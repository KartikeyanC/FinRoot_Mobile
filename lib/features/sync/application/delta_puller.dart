import 'package:drift/drift.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/local/app_database.dart';
import '../data/pull_gateway.dart';
import '../data/row_mappers.dart';
import '../domain/sync_types.dart';

class PullRunResult {
  const PullRunResult({this.rowsApplied = 0, this.pruned = 0});
  final int rowsApplied;
  final int pruned;
}

/// Pulls server changes into the cache.
///
/// - **delta**: `updated_at > cursor` per entity, cursor from `sync_states`.
/// - **full**: no cursor, plus a prune of synced cache rows the server no
///   longer has (a web-side hard delete). Transactions are bounded to a recent
///   window so the cache stays small.
///
/// A row with unsynced local changes is never overwritten — only its
/// `serverUpdatedAt` is recorded, so the push path (which sends full state) is
/// still last-write-wins.
class DeltaPuller {
  DeltaPuller(
    this._db,
    this._gateway, {
    this.pageSize = 500,
    this.maxPages = 40,
    this.transactionWindow = const Duration(days: 180),
  });

  final AppDatabase _db;
  final PullGateway _gateway;
  final int pageSize;
  final int maxPages;
  final Duration transactionWindow;

  final _log = AppLog.of('sync.pull');

  Future<PullRunResult> run(String tenantId, {bool full = false}) async {
    final windowStart = DateTime.now().toUtc().subtract(transactionWindow);
    var applied = 0;
    var pruned = 0;
    Object? firstError;
    StackTrace? firstStack;
    for (final entity in SyncEntity.values) {
      // One table failing (a server error, a schema mismatch) must not stop
      // the others from refreshing; the first error is still reported.
      try {
        final r = await _pullEntity(
          entity,
          tenantId,
          full: full,
          windowStart: windowStart,
        );
        applied += r.rowsApplied;
        pruned += r.pruned;
      } catch (error, stack) {
        _log.warning('pull ${entity.key} failed: ${error.runtimeType}');
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    _log.info(
      'pull ${full ? "full" : "delta"}: $applied applied, $pruned pruned',
    );
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
    return PullRunResult(rowsApplied: applied, pruned: pruned);
  }

  Future<PullRunResult> _pullEntity(
    SyncEntity entity,
    String tenantId, {
    required bool full,
    required DateTime windowStart,
  }) async {
    final state = await _db.syncStateDao.forEntity(entity.key, tenantId);
    DateTime? cursor = full ? null : state?.cursor;
    DateTime? maxUpdated = cursor;
    var applied = 0;
    var pages = 0;
    var skippedRows = 0;

    while (pages < maxPages) {
      final page = await _gateway.fetchSince(
        entity,
        tenantId,
        since: cursor,
        limit: pageSize,
        transactionWindowStart: entity == SyncEntity.transaction
            ? windowStart
            : null,
      );
      if (page.rows.isEmpty) break;

      await _db.transaction(() async {
        for (final row in page.rows) {
          // A row this app can't read (a null the web allows, a value it
          // doesn't know) is skipped, not fatal: failing here rolled back the
          // page and kept the cursor still, so every later sync failed on the
          // same row and the red banner never cleared.
          try {
            final u = RowMappers.updatedAt(row);
            if (maxUpdated == null || u.isAfter(maxUpdated!)) maxUpdated = u;
            await _applyRow(entity, row);
          } catch (error) {
            skippedRows++;
            _log.warning(
              'skipped unreadable ${entity.key} row ${row['id']}: ${error.runtimeType}',
            );
          }
        }
      });

      applied += page.rows.length;
      cursor = maxUpdated;
      pages++;
      if (!page.hasMore) break;
    }

    if (skippedRows > 0) {
      _log.warning('${entity.key}: $skippedRows unreadable rows skipped');
    }

    var pruned = 0;
    if (full) {
      pruned = await _prune(entity, tenantId, windowStart);
    }

    if (maxUpdated != null) {
      await _db.syncStateDao.recordPull(
        entity: entity.key,
        tenantId: tenantId,
        cursor: maxUpdated!,
        wasFullSync: full,
      );
    } else if (full) {
      // A full sync that found nothing still moves the bookmark forward.
      await _db.syncStateDao.recordPull(
        entity: entity.key,
        tenantId: tenantId,
        cursor: DateTime.now().toUtc(),
        wasFullSync: true,
      );
    }

    return PullRunResult(rowsApplied: applied, pruned: pruned);
  }

  Future<void> _applyRow(SyncEntity entity, Map<String, dynamic> row) async {
    final id = RowMappers.id(row);

    if (RowMappers.isTombstoned(entity, row)) {
      await _deleteLocal(entity, id);
      return;
    }

    // Do not clobber a row that has an unsynced local change — only note the
    // server's timestamp so the push can resolve the conflict.
    final localStatus = await _localSyncStatus(entity, id);
    if (localStatus != null && localStatus != LocalSyncStatus.synced) {
      await _db.customUpdate(
        'UPDATE ${entity.localTable} SET server_updated_at = ? WHERE id = ?',
        variables: [
          Variable<DateTime>(RowMappers.updatedAt(row)),
          Variable<String>(id),
        ],
      );
      return;
    }

    switch (entity) {
      case SyncEntity.transaction:
        await _db
            .into(_db.localTransactions)
            .insertOnConflictUpdate(RowMappers.transaction(row));
      case SyncEntity.account:
        await _db
            .into(_db.localAccounts)
            .insertOnConflictUpdate(RowMappers.account(row));
      case SyncEntity.tracker:
        await _db
            .into(_db.localTrackers)
            .insertOnConflictUpdate(RowMappers.tracker(row));
      case SyncEntity.budget:
        await _db
            .into(_db.localBudgets)
            .insertOnConflictUpdate(RowMappers.budget(row));
      case SyncEntity.goal:
        await _db
            .into(_db.localGoals)
            .insertOnConflictUpdate(RowMappers.goal(row));
    }
  }

  Future<LocalSyncStatus?> _localSyncStatus(
    SyncEntity entity,
    String id,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT sync_status FROM ${entity.localTable} WHERE id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    if (rows.isEmpty) return null;
    return LocalSyncStatus.values.byName(
      rows.first.read<String>('sync_status'),
    );
  }

  Future<void> _deleteLocal(SyncEntity entity, String id) {
    return _db.customUpdate(
      'DELETE FROM ${entity.localTable} WHERE id = ? '
      "AND sync_status = 'synced'",
      variables: [Variable<String>(id)],
      updateKind: UpdateKind.delete,
    );
  }

  /// Remove synced cache rows the server no longer lists (a hard delete on
  /// web). Never touches a row with a pending local change.
  Future<int> _prune(
    SyncEntity entity,
    String tenantId,
    DateTime windowStart,
  ) async {
    final live = await _gateway.fetchLiveIds(
      entity,
      tenantId,
      transactionWindowStart: entity == SyncEntity.transaction
          ? windowStart
          : null,
    );

    // Build a NOT IN (...) with bound variables. `live` is a few hundred ids.
    final placeholders = live.isEmpty
        ? null
        : List.filled(live.length, '?').join(',');
    final windowClause = entity == SyncEntity.transaction
        ? 'AND occurred_at >= ?'
        : '';
    final notInClause = placeholders == null
        ? ''
        : 'AND id NOT IN ($placeholders)';

    final vars = <Variable<Object>>[
      Variable<String>(tenantId),
      if (entity == SyncEntity.transaction) Variable<DateTime>(windowStart),
      ...live.map(Variable<String>.new),
    ];

    return _db.customUpdate(
      'DELETE FROM ${entity.localTable} '
      "WHERE tenant_id = ? AND sync_status = 'synced' $windowClause $notInClause",
      variables: vars,
      updateKind: UpdateKind.delete,
    );
  }
}
