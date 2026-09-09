import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../../domain/constants.dart';
import '../domain/transaction.dart';

/// Reads transactions out of the local cache (M4). A cache, not a source of
/// truth — these are offline / instant reads; the server stays authoritative
/// and the sync engine (M5) keeps the cache fresh. No aggregation happens here
/// (ADR-0006): callers get rows, never totals.
///
/// M6 needs the recent feed and a recent-activity count. M8 extends this with
/// the full ledger, grouping, search and filters.
class TransactionsRepository {
  TransactionsRepository(this._db);

  final AppDatabase _db;

  /// The most recent transactions for [tenantId], newest first. Rows deleted
  /// offline and not yet confirmed (`pendingDelete`) are excluded — they are
  /// kept in the cache only so a failed delete can retry.
  Stream<List<TransactionEntity>> watchRecent(
    String tenantId, {
    int limit = 6,
  }) {
    final query = _db.select(_db.localTransactions)
      ..where(
        (t) =>
            t.tenantId.equals(tenantId) &
            t.syncStatus.equalsValue(LocalSyncStatus.pendingDelete).not(),
      )
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.cachedAt),
      ])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  /// One transaction by id, live. Null once it is gone (a confirmed delete).
  Stream<TransactionEntity?> watchById(String id) {
    final query = _db.select(_db.localTransactions)
      ..where((t) => t.id.equals(id))
      ..limit(1);
    return query.watch().map(
      (rows) => rows.isEmpty ? null : _toEntity(rows.first),
    );
  }

  /// The ledger (M8): all cached transactions for [tenantId], newest first,
  /// optionally narrowed by [type], a text [search] over note + category, and
  /// an [accountId] (either side of a transfer). Capped at [limit] — the cache
  /// itself is bounded to ~180 days (M5 `DeltaPuller`).
  Stream<List<TransactionEntity>> watchLedger(
    String tenantId, {
    TxnType? type,
    String? search,
    String? accountId,
    int limit = 300,
  }) {
    final q = search?.trim().toLowerCase();
    final query = _db.select(_db.localTransactions)
      ..where((t) {
        var cond =
            t.tenantId.equals(tenantId) &
            t.syncStatus.equalsValue(LocalSyncStatus.pendingDelete).not();
        if (type != null) {
          cond = cond & t.type.equals(type.wire);
        }
        if (accountId != null) {
          cond = cond &
              (t.accountId.equals(accountId) |
                  t.transferToAccountId.equals(accountId));
        }
        if (q != null && q.isNotEmpty) {
          final like = '%$q%';
          cond = cond &
              (t.description.lower().like(like) |
                  t.category.lower().like(like));
        }
        return cond;
      })
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm.desc(t.cachedAt),
      ])
      ..limit(limit);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  /// How many transactions the cache holds for [tenantId] with an `occurred_at`
  /// on or after [since]. A count of records — not a sum of money. The cache's
  /// 180-day transaction window (M5 `DeltaPuller`) covers any month-to-date or
  /// last-30-days range.
  Stream<int> watchCountSince(String tenantId, DateTime since) {
    final count = _db.localTransactions.id.count();
    final query = _db.selectOnly(_db.localTransactions)
      ..addColumns([count])
      ..where(
        _db.localTransactions.tenantId.equals(tenantId) &
            _db.localTransactions.syncStatus
                .equalsValue(LocalSyncStatus.pendingDelete)
                .not() &
            _db.localTransactions.occurredAt.isBiggerOrEqualValue(since),
      );
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  TransactionEntity _toEntity(LocalTransactionRow r) {
    return TransactionEntity(
      id: r.id,
      type: TxnType.fromWire(r.type),
      amount: Money(r.amount, r.currency),
      category: r.category,
      occurredAt: r.occurredAt,
      description: r.description,
      trackerId: r.trackerId,
      accountId: r.accountId,
      transferToAccountId: r.transferToAccountId,
      paymentMode: r.paymentMode,
      syncState: r.syncStatus,
    );
  }
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(appDatabaseProvider)),
  name: 'transactionsRepository',
);
