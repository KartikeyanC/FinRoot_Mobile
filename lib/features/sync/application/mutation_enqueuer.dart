import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';

const _uuid = Uuid();

/// The desired state of a transaction, in the shape the mutation envelope's
/// `payload` uses. Built by the transaction feature (M7); consumed here.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.currency,
    required this.category,
    required this.occurredAt,
    this.description,
    this.accountId,
    this.paymentMode,
    this.transferToAccountId,
    this.trackerId,
  });

  final String type; // income | expense | transfer
  final String amount; // numeric(14,2) string — Money.toStorageString()
  final String currency;
  final String category;
  final DateTime occurredAt;
  final String? description;
  final String? accountId;
  final String? paymentMode;
  final String? transferToAccountId;
  final String? trackerId;

  Map<String, dynamic> toPayload() => {
    'type': type,
    'amount': amount,
    'currency': currency,
    'category': category,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'description': description,
    'account_id': accountId,
    'payment_mode': paymentMode,
    'transfer_to_account_id': transferToAccountId,
    'tracker_id': trackerId,
  };
}

/// Writes a transaction change to the local cache and the outbox in one
/// database transaction, so the UI updates instantly and the change is
/// guaranteed to reach the sync queue. Returns the transaction's id (the same
/// id locally and, after M1.5, on the server).
class MutationEnqueuer {
  MutationEnqueuer(this._db);

  final AppDatabase _db;

  Future<String> create(
    String tenantId,
    String userId,
    TransactionDraft d,
  ) async {
    final id = _uuid.v4();
    final mutationId = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.localTransactions)
          .insert(
            LocalTransactionsCompanion.insert(
              id: id,
              tenantId: tenantId,
              userId: Value(userId),
              type: d.type,
              amount: _decimal(d.amount),
              currency: Value(d.currency),
              category: d.category,
              occurredAt: d.occurredAt,
              description: Value(d.description),
              accountId: Value(d.accountId),
              paymentMode: Value(d.paymentMode),
              transferToAccountId: Value(d.transferToAccountId),
              trackerId: Value(d.trackerId),
              syncStatus: const Value(LocalSyncStatus.pendingCreate),
              pendingMutationId: Value(mutationId),
            ),
          );
      await _db.syncOutboxDao.enqueue(
        mutationId: mutationId,
        tenantId: tenantId,
        operation: OutboxOperation.createTransaction,
        entityLocalId: id,
        payload: d.toPayload(),
      );
    });
    return id;
  }

  Future<void> update(String tenantId, String id, TransactionDraft d) async {
    final mutationId = _uuid.v4();
    await _db.transaction(() async {
      await (_db.update(
        _db.localTransactions,
      )..where((t) => t.id.equals(id))).write(
        LocalTransactionsCompanion(
          type: Value(d.type),
          amount: Value(_decimal(d.amount)),
          currency: Value(d.currency),
          category: Value(d.category),
          occurredAt: Value(d.occurredAt),
          description: Value(d.description),
          accountId: Value(d.accountId),
          paymentMode: Value(d.paymentMode),
          transferToAccountId: Value(d.transferToAccountId),
          trackerId: Value(d.trackerId),
          syncStatus: const Value(LocalSyncStatus.pendingUpdate),
          pendingMutationId: Value(mutationId),
        ),
      );
      await _db.syncOutboxDao.enqueue(
        mutationId: mutationId,
        tenantId: tenantId,
        operation: OutboxOperation.updateTransaction,
        entityLocalId: id,
        payload: d.toPayload(),
      );
    });
  }

  Future<void> delete(String tenantId, String id) async {
    final mutationId = _uuid.v4();
    await _db.transaction(() async {
      await (_db.update(
        _db.localTransactions,
      )..where((t) => t.id.equals(id))).write(
        LocalTransactionsCompanion(
          syncStatus: const Value(LocalSyncStatus.pendingDelete),
          pendingMutationId: Value(mutationId),
        ),
      );
      await _db.syncOutboxDao.enqueue(
        mutationId: mutationId,
        tenantId: tenantId,
        operation: OutboxOperation.deleteTransaction,
        entityLocalId: id,
      );
    });
  }

  static Decimal _decimal(String s) => Decimal.parse(s);
}

final mutationEnqueuerProvider = Provider<MutationEnqueuer>(
  (ref) => MutationEnqueuer(ref.watch(appDatabaseProvider)),
  name: 'mutationEnqueuer',
);
