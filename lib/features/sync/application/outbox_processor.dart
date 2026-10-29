import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/local/app_database.dart';
import '../data/mutation_gateway.dart';
import '../data/row_mappers.dart';
import '../domain/failure_disposition.dart';
import '../domain/sync_types.dart';

class OutboxRunResult {
  const OutboxRunResult({
    this.synced = 0,
    this.failed = 0,
    this.retried = 0,
    this.stopped = false,
    this.backendMissing = false,
    this.lastError,
  });

  final int synced;
  final int failed;
  final int retried;

  /// The run halted early — offline, a network error, or the RPC not deployed.
  final bool stopped;
  final bool backendMissing;
  final String? lastError;
}

/// Drains `sync_outbox` through `apply_transaction_mutation`.
///
/// The retry/permanent decision is `classifyMutationFailure`
/// (`backend/M1.5_CLIENT_CONTRACT.md` §5). A network-class failure stops the
/// whole run — there is no point trying the next entry while the connection is
/// down.
class OutboxProcessor {
  OutboxProcessor(this._db, this._gateway);

  final AppDatabase _db;
  final MutationGateway _gateway;

  final _log = AppLog.of('sync.outbox');
  SyncOutboxDao get _dao => _db.syncOutboxDao;

  Future<OutboxRunResult> run({int batchLimit = 50}) async {
    final batch = await _dao.pendingBatch(limit: batchLimit);
    if (batch.isEmpty) return const OutboxRunResult();

    var synced = 0, failed = 0, retried = 0;
    for (final entry in batch) {
      await _dao.markInFlight(entry.id);
      try {
        final result = await _gateway.apply(entry);
        // The server has it now. Refreshing the cached row from its reply is
        // best-effort: if that throws, the entry must still be cleared (it
        // used to stay "in flight" forever), and the next pull fixes the row.
        try {
          await _reconcileSuccess(entry, result);
        } catch (error) {
          _log.warning('saved, but the cache refresh failed: ${error.runtimeType}');
        }
        await _dao.markSynced(entry.id);
        synced++;
        _log.info('${entry.operation.name} ${result.status}');
      } on Failure catch (f) {
        final disposition = classifyMutationFailure(f);
        switch (disposition) {
          case FailureDisposition.holdBackendMissing:
            await _dao.markRetry(entry.id, describeFailure(f));
            _log.warning(
              'apply_transaction_mutation not deployed — holding queue',
            );
            return OutboxRunResult(
              synced: synced,
              failed: failed,
              retried: retried,
              stopped: true,
              backendMissing: true,
              lastError: 'Waiting for a backend update to finish syncing.',
            );

          case FailureDisposition.retry:
            // Temporary (no signal, a timeout, a login refresh): never the
            // entry's fault, so it is never parked as "didn't sync" — it was,
            // after [maxAttempts] tries, and that is what kept showing the
            // red banner. The engine's cool-off spaces the retries out.
            await _dao.markRetry(entry.id, describeFailure(f));
            retried++;
            return OutboxRunResult(
              synced: synced,
              failed: failed,
              retried: retried,
              stopped: true,
              lastError: f.message,
            );

          case FailureDisposition.permanent:
            await _dao.markFailed(entry.id, describeFailure(f));
            await _flagCacheFailed(entry);
            failed++;
            _log.warning('${entry.operation.name} failed permanently');

          case FailureDisposition.reconcileGone:
            await _dropLocal(entry);
            await _dao.markSynced(entry.id);
            synced++;
            _log.info('${entry.operation.name}: row already gone — reconciled');
        }
      }
    }

    return OutboxRunResult(synced: synced, failed: failed, retried: retried);
  }

  Future<void> _reconcileSuccess(OutboxEntry entry, MutationResult result) {
    final rowGone =
        result.deleted ||
        (result.transaction == null && entry.operation.isCreate);
    if (rowGone) return _dropLocal(entry);

    final row = result.transaction;
    if (row != null) {
      return _db
          .into(_db.localTransactions)
          .insertOnConflictUpdate(RowMappers.transaction(row));
    }
    // An update/replay with no row echoed — just clear the pending flag.
    return (_db.update(
      _db.localTransactions,
    )..where((t) => t.id.equals(entry.entityLocalId))).write(
      const LocalTransactionsCompanion(
        syncStatus: Value(LocalSyncStatus.synced),
        pendingMutationId: Value(null),
      ),
    );
  }

  Future<void> _flagCacheFailed(OutboxEntry entry) {
    return (_db.update(
      _db.localTransactions,
    )..where((t) => t.id.equals(entry.entityLocalId))).write(
      const LocalTransactionsCompanion(
        syncStatus: Value(LocalSyncStatus.failed),
      ),
    );
  }

  Future<void> _dropLocal(OutboxEntry entry) {
    return (_db.delete(
      _db.localTransactions,
    )..where((t) => t.id.equals(entry.entityLocalId))).go();
  }
}

/// The failure as the person sees it, plus the server's own words and code
/// when there are any — "That didn't pass a check" alone gave nobody a way to
/// tell what was wrong.
String describeFailure(Failure f) {
  final cause = f.cause;
  if (cause is PostgrestException) {
    final detail = [
      if (cause.code != null && cause.code!.isNotEmpty) cause.code,
      cause.message,
      if (cause.details != null && '${cause.details}'.isNotEmpty) '${cause.details}',
    ].join(' · ');
    return '${f.message} ($detail)';
  }
  if (cause != null && f is UnexpectedFailure) return '${f.message} ($cause)';
  return f.message;
}
