import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/features/sync/application/sync_engine.dart';
import 'package:finroot_mobile/features/sync/data/mutation_gateway.dart';
import 'package:finroot_mobile/features/sync/data/pull_gateway.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '_fakes.dart';

void main() {
  late AppDatabase db;
  late FakeMutationGateway mutation;
  late FakePullGateway pull;

  ProviderContainer makeContainer({bool online = true, String? tenant = 't1'}) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mutationGatewayProvider.overrideWithValue(mutation),
        pullGatewayProvider.overrideWithValue(pull),
        isSignedInProvider.overrideWithValue(true),
        isOnlineProvider.overrideWithValue(online),
        currentTenantIdProvider.overrideWithValue(tenant),
      ],
    );
  }

  setUp(() {
    db = AppDatabase.forTesting();
    mutation = FakeMutationGateway();
    pull = FakePullGateway();
  });
  tearDown(() => db.close());

  test('offline → snapshot phase offline, nothing sent', () async {
    final c = makeContainer(online: false);
    addTearDown(c.dispose);
    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).phase, SyncPhase.offline);
    expect(mutation.calls, isEmpty);
  });

  test('no workspace → does nothing', () async {
    final c = makeContainer(tenant: null);
    addTearDown(c.dispose);
    await c.read(syncEngineProvider.notifier).syncNow();
    expect(c.read(syncEngineProvider).phase, SyncPhase.idle);
  });

  test('happy path: push then pull → phase done, counts zero', () async {
    // one queued create
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 't-1',
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('10.00'),
            category: 'Other',
            occurredAt: DateTime.utc(2026, 9, 8),
            syncStatus: const Value(LocalSyncStatus.pendingCreate),
          ),
        );
    await db.syncOutboxDao.enqueue(
      mutationId: 'm-1',
      tenantId: 't1',
      operation: OutboxOperation.createTransaction,
      entityLocalId: 't-1',
      payload: {'type': 'expense', 'amount': '10.00', 'category': 'Other'},
    );
    mutation.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: 't-1',
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 12),
        ),
      }),
    );
    // one server row to pull
    pull.rows[SyncEntity.transaction]!.add(
      serverTxn(
        id: 's-1',
        tenant: 't1',
        updatedAt: DateTime.utc(2026, 9, 8, 13),
      ),
    );

    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(syncEngineProvider.notifier).syncNow();

    final snap = c.read(syncEngineProvider);
    expect(snap.phase, SyncPhase.done);
    expect(snap.pendingCount, 0);
    expect(snap.failedCount, 0);
    expect(snap.lastSyncedAt, isNotNull);
    expect(await db.syncStateDao.forEntity('transaction', 't1'), isNotNull);
  });

  test(
    'backend missing → phase failed, entry held, cool-off engaged',
    () async {
      await db.syncOutboxDao.enqueue(
        mutationId: 'm-x',
        tenantId: 't1',
        operation: OutboxOperation.createTransaction,
        entityLocalId: 'x',
        payload: {'type': 'expense', 'amount': '1.00', 'category': 'Other'},
      );
      mutation.always = const UnexpectedFailure(
        cause: PostgrestException(message: 'no fn', code: 'PGRST202'),
      );

      final c = makeContainer();
      addTearDown(c.dispose);
      await c.read(syncEngineProvider.notifier).syncNow();

      expect(c.read(syncEngineProvider).phase, SyncPhase.failed);
      expect(c.read(syncEngineProvider).lastError, contains('backend'));
      expect(await db.syncOutboxDao.countPending(), 1);

      // A second immediate run is skipped by the cool-off.
      mutation.calls.clear();
      await c.read(syncEngineProvider.notifier).syncNow();
      expect(mutation.calls, isEmpty);
      // ...but force overrides it.
      await c.read(syncEngineProvider.notifier).syncNow(force: true);
      expect(mutation.calls, isNotEmpty);
    },
  );

  test('retryFailed requeues and re-runs', () async {
    await db.syncOutboxDao.enqueue(
      mutationId: 'm-r',
      tenantId: 't1',
      operation: OutboxOperation.deleteTransaction,
      entityLocalId: 'r',
    );
    final entry = (await db.syncOutboxDao.pendingBatch()).single;
    await db.syncOutboxDao.markInFlight(entry.id);
    await db.syncOutboxDao.markFailed(entry.id, 'boom');
    expect(await db.syncOutboxDao.countFailed(), 1);

    mutation.enqueueResult(
      const MutationResult(status: 'replayed', deleted: true),
    );

    final c = makeContainer();
    addTearDown(c.dispose);
    await c.read(syncEngineProvider.notifier).retryFailed();

    expect(await db.syncOutboxDao.countFailed(), 0);
    expect(await db.syncOutboxDao.countPending(), 0);
  });
}
