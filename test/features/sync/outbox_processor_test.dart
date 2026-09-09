import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/sync/application/outbox_processor.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeMutationGateway gateway;
  late OutboxProcessor processor;

  setUp(() {
    db = AppDatabase.forTesting();
    gateway = FakeMutationGateway();
    processor = OutboxProcessor(db, gateway, maxAttempts: 3);
  });
  tearDown(() => db.close());

  Future<void> seedPendingCreate(String id, {String tenant = 't1'}) async {
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: id,
            tenantId: tenant,
            type: 'expense',
            amount: Decimal.parse('10.00'),
            category: 'Other',
            occurredAt: DateTime.utc(2026, 9, 8),
            syncStatus: const Value(LocalSyncStatus.pendingCreate),
            pendingMutationId: Value('m-$id'),
          ),
        );
    await db.syncOutboxDao.enqueue(
      mutationId: 'm-$id',
      tenantId: tenant,
      operation: OutboxOperation.createTransaction,
      entityLocalId: id,
      payload: {'type': 'expense', 'amount': '10.00', 'category': 'Other'},
    );
  }

  test(
    'applied → cache row synced, server id honoured, outbox cleared',
    () async {
      await seedPendingCreate('txn-1');
      gateway.enqueueResult(
        MutationResult.fromRpc({
          'status': 'applied',
          'deleted': false,
          'transaction': serverTxn(
            id: 'txn-1',
            tenant: 't1',
            amount: '10.00',
            updatedAt: DateTime.utc(2026, 9, 8, 12),
          ),
        }),
      );

      final result = await processor.run();

      expect(result.synced, 1);
      expect(await db.syncOutboxDao.countPending(), 0);
      final row = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('txn-1'))).getSingle();
      expect(row.syncStatus, LocalSyncStatus.synced);
      expect(row.serverUpdatedAt, isNotNull);
    },
  );

  test('replayed is treated exactly like applied', () async {
    await seedPendingCreate('txn-2');
    gateway.enqueueResult(
      MutationResult.fromRpc({
        'status': 'replayed',
        'deleted': false,
        'transaction': serverTxn(
          id: 'txn-2',
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 12),
        ),
      }),
    );
    final result = await processor.run();
    expect(result.synced, 1);
    expect(await db.syncOutboxDao.countPending(), 0);
  });

  test('network failure → entry stays pending, run stops', () async {
    await seedPendingCreate('a');
    await seedPendingCreate('b');
    gateway.enqueueError(const NetworkFailure());

    final result = await processor.run();

    expect(result.stopped, isTrue);
    expect(result.synced, 0);
    expect(await db.syncOutboxDao.countPending(), 2); // neither sent
    // 'b' was never attempted.
    expect(gateway.calls.length, 1);
  });

  test(
    'attempts cap: a persistently failing entry is parked as failed',
    () async {
      await seedPendingCreate('c');
      gateway.always = const NetworkFailure();

      for (var i = 0; i < 3; i++) {
        await processor.run();
      }
      final entry = await db.syncOutboxDao.byMutationId('m-c');
      expect(entry!.status, OutboxStatus.failed);
      expect(entry.attempts, 3);
      final row = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('c'))).getSingle();
      expect(row.syncStatus, LocalSyncStatus.failed);
    },
  );

  test('permanent failure → failed + cache flagged, run continues', () async {
    await seedPendingCreate('perm');
    await seedPendingCreate('ok');
    gateway.enqueueError(const PermissionFailure());
    gateway.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: 'ok',
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 12),
        ),
      }),
    );

    final result = await processor.run();

    expect(result.failed, 1);
    expect(result.synced, 1);
    final perm = await db.syncOutboxDao.byMutationId('m-perm');
    expect(perm!.status, OutboxStatus.failed);
  });

  test('P0002 on a delete → local row dropped, entry cleared', () async {
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 'gone',
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('5.00'),
            category: 'Other',
            occurredAt: DateTime.utc(2026, 9, 8),
            syncStatus: const Value(LocalSyncStatus.pendingDelete),
          ),
        );
    await db.syncOutboxDao.enqueue(
      mutationId: 'm-gone',
      tenantId: 't1',
      operation: OutboxOperation.deleteTransaction,
      entityLocalId: 'gone',
    );
    gateway.enqueueError(
      const UnexpectedFailure(
        cause: PostgrestException(
          message: 'no such transaction',
          code: 'P0002',
        ),
      ),
    );

    final result = await processor.run();

    expect(result.synced, 1);
    expect(await db.syncOutboxDao.countPending(), 0);
    final row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('gone'))).getSingleOrNull();
    expect(row, isNull);
  });

  test('backend missing (PGRST202) → holds the whole queue', () async {
    await seedPendingCreate('x');
    gateway.enqueueError(
      const UnexpectedFailure(
        cause: PostgrestException(message: 'no function', code: 'PGRST202'),
      ),
    );
    final result = await processor.run();
    expect(result.backendMissing, isTrue);
    expect(result.stopped, isTrue);
    expect(await db.syncOutboxDao.countPending(), 1);
  });
}
