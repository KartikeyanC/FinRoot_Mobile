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
    processor = OutboxProcessor(db, gateway);
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
    'a temporary failure is never parked as "didn\'t sync", however often',
    () async {
      // This used to give up after a few tries and show the red banner for
      // an entry that had nothing wrong with it.
      await seedPendingCreate('c');
      gateway.always = const NetworkFailure();

      for (var i = 0; i < 10; i++) {
        await processor.run();
      }
      final entry = await db.syncOutboxDao.byMutationId('m-c');
      expect(entry!.status, OutboxStatus.pending);
      expect(await db.syncOutboxDao.countFailed(), 0);
      final row = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('c'))).getSingle();
      expect(row.syncStatus, LocalSyncStatus.pendingCreate);

      gateway.always = null;
      gateway.enqueueResult(const MutationResult(status: 'applied', deleted: false));
      await processor.run();
      expect(await db.syncOutboxDao.byMutationId('m-c'), isNull, reason: 'sent once the network is back');
    },
  );

  test('an entry left in flight by a closed app is sent again', () async {
    await seedPendingCreate('orphan');
    final e = await db.syncOutboxDao.byMutationId('m-orphan');
    await db.syncOutboxDao.markInFlight(e!.id); // the app died right here

    // Moments later another sender must not grab it (it may still be going)…
    expect(await db.syncOutboxDao.pendingBatch(), isEmpty);
    // …but once it is clearly abandoned, it goes out again.
    final later = DateTime.now().add(const Duration(minutes: 3));
    expect((await db.syncOutboxDao.pendingBatch(now: later)).single.mutationId, 'm-orphan');
  });

  test('if refreshing the cache after a save throws, the entry still clears', () async {
    await seedPendingCreate('r');
    // A server row the cache can't read (no id) — the save itself worked.
    gateway.enqueueResult(
      const MutationResult(status: 'applied', deleted: false, transaction: {'amount': 1}),
    );
    await processor.run();
    expect(await db.syncOutboxDao.byMutationId('m-r'), isNull);
  });

  test('a refused change keeps the server\'s own reason and code', () async {
    await seedPendingCreate('why');
    gateway.enqueueError(
      const ValidationFailure(
        "That didn't pass a check. Review the details and try again.",
        cause: PostgrestException(
          message: 'new row violates check constraint "transactions_type_check"',
          code: '23514',
        ),
      ),
    );
    await processor.run();
    final e = await db.syncOutboxDao.byMutationId('m-why');
    expect(e!.status, OutboxStatus.failed);
    expect(e.lastError, contains('23514'));
    expect(e.lastError, contains('transactions_type_check'));
  });

  test('Retry starts the attempt count again', () async {
    await seedPendingCreate('x');
    final e = await db.syncOutboxDao.byMutationId('m-x');
    for (var i = 0; i < 5; i++) {
      await db.syncOutboxDao.markInFlight(e!.id);
    }
    await db.syncOutboxDao.markFailed(e!.id, 'boom');
    await db.syncOutboxDao.requeueFailed();
    final again = await db.syncOutboxDao.byMutationId('m-x');
    expect(again!.status, OutboxStatus.pending);
    expect(again.attempts, 0);
  });

  test('self-heal only re-tries changes refused a while ago', () async {
    await seedPendingCreate('old');
    final e = await db.syncOutboxDao.byMutationId('m-old');
    await db.syncOutboxDao.markInFlight(e!.id);
    await db.syncOutboxDao.markFailed(e.id, 'boom');

    final now = DateTime.now();
    expect(await db.syncOutboxDao.requeueFailed(olderThan: now.subtract(const Duration(minutes: 30))), 0);
    expect(await db.syncOutboxDao.requeueFailed(olderThan: now.add(const Duration(minutes: 1))), 1);
  });

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
