import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/sync/application/mutation_enqueuer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MutationEnqueuer enqueuer;

  setUp(() {
    db = AppDatabase.forTesting();
    enqueuer = MutationEnqueuer(db);
  });
  tearDown(() => db.close());

  test(
    'create writes a pending cache row and a matching outbox entry',
    () async {
      final draft = TransactionDraft(
        type: 'expense',
        amount: '18600.00',
        currency: 'INR',
        category: 'Labour',
        occurredAt: DateTime.utc(2026, 9, 8, 10, 30),
        trackerId: 'trk-home',
      );

      final id = await enqueuer.create('t1', 'u1', draft);

      final row = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingCreate);
      expect(row.amount, Decimal.parse('18600.00'));
      expect(row.trackerId, 'trk-home');
      expect(row.pendingMutationId, isNotNull);

      final entry = await db.syncOutboxDao.byMutationId(row.pendingMutationId!);
      expect(entry!.operation, OutboxOperation.createTransaction);
      expect(entry.entityLocalId, id);
      final payload = jsonDecode(entry.payload!) as Map<String, dynamic>;
      expect(payload['amount'], '18600.00');
      expect(payload['tracker_id'], 'trk-home');
      expect(payload['occurred_at'], startsWith('2026-09-08T10:30'));
    },
  );

  test('update flips status to pendingUpdate and queues an update', () async {
    final id = await enqueuer.create(
      't1',
      'u1',
      TransactionDraft(
        type: 'expense',
        amount: '10.00',
        currency: 'INR',
        category: 'Other',
        occurredAt: DateTime.utc(2026, 9, 8),
      ),
    );
    await db.syncOutboxDao.requeueFailed(); // no-op, just exercising the db

    await enqueuer.update(
      't1',
      id,
      TransactionDraft(
        type: 'expense',
        amount: '12.00',
        currency: 'INR',
        category: 'Food & Dining',
        occurredAt: DateTime.utc(2026, 9, 8),
      ),
    );

    final row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(row.syncStatus, LocalSyncStatus.pendingUpdate);
    expect(row.category, 'Food & Dining');
    expect(row.amount, Decimal.parse('12.00'));

    final entries = await db.syncOutboxDao.pendingBatch();
    expect(entries.map((e) => e.operation), [
      OutboxOperation.createTransaction,
      OutboxOperation.updateTransaction,
    ]);
  });

  test(
    'delete flips status to pendingDelete and queues a payload-less delete',
    () async {
      final id = await enqueuer.create(
        't1',
        'u1',
        TransactionDraft(
          type: 'expense',
          amount: '10.00',
          currency: 'INR',
          category: 'Other',
          occurredAt: DateTime.utc(2026, 9, 8),
        ),
      );

      await enqueuer.delete('t1', id);

      final row = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingDelete);

      final del = (await db.syncOutboxDao.pendingBatch()).firstWhere(
        (e) => e.operation == OutboxOperation.deleteTransaction,
      );
      expect(del.entityLocalId, id);
      expect(del.payload, isNull);
    },
  );
}
