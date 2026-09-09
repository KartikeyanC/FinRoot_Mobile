import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/features/sync/application/mutation_enqueuer.dart';
import 'package:finroot_mobile/features/sync/application/sync_engine.dart';
import 'package:finroot_mobile/features/sync/data/mutation_gateway.dart';
import 'package:finroot_mobile/features/sync/data/pull_gateway.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/sync/_fakes.dart';

/// M19 — the offline-first loop end to end, over a real (in-memory) Drift
/// database: capture through `MutationEnqueuer` while offline → the cache shows
/// it immediately with a pending marker → reconnect → `SyncEngine` drains the
/// outbox through the gateway → the cache row is confirmed. Then edit, delete
/// and a transient-failure retry.

TransactionDraft _draft({
  String type = 'expense',
  String amount = '250.00',
  String category = 'Food & Dining',
}) => TransactionDraft(
  type: type,
  amount: amount,
  currency: 'INR',
  category: category,
  occurredAt: DateTime.utc(2026, 9, 8, 10, 30),
);

void main() {
  late AppDatabase db;
  late MutationEnqueuer enqueuer;
  late FakeMutationGateway mutation;
  late FakePullGateway pull;

  ProviderContainer container({required bool online}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mutationGatewayProvider.overrideWithValue(mutation),
        pullGatewayProvider.overrideWithValue(pull),
        isSignedInProvider.overrideWithValue(true),
        isOnlineProvider.overrideWithValue(online),
        currentTenantIdProvider.overrideWithValue('t1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<LocalTransactionRow?> row(String id) => (db.select(
    db.localTransactions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> outboxDepth() async =>
      (await db.syncOutboxDao.pendingBatch()).length;

  setUp(() {
    db = AppDatabase.forTesting();
    enqueuer = MutationEnqueuer(db);
    mutation = FakeMutationGateway();
    pull = FakePullGateway();
  });
  tearDown(() => db.close());

  test('capture offline → reconnect → the row is confirmed', () async {
    // 1. offline capture
    final offline = container(online: false);
    final id = await enqueuer.create('t1', 'u1', _draft());

    final pending = await row(id);
    expect(pending!.syncStatus, LocalSyncStatus.pendingCreate);
    expect(pending.amount, Decimal.parse('250.00'));
    expect(pending.pendingMutationId, isNotNull);
    expect(await outboxDepth(), 1);

    // a sync attempt while offline sends nothing
    await offline.read(syncEngineProvider.notifier).syncNow();
    expect(mutation.calls, isEmpty);
    expect((await row(id))!.syncStatus, LocalSyncStatus.pendingCreate);

    // 2. reconnect — the server accepts the create
    mutation.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: id,
          tenant: 't1',
          amount: '250.00',
          updatedAt: DateTime.utc(2026, 9, 8, 11),
        ),
      }),
    );

    final onlineC = container(online: true);
    await onlineC.read(syncEngineProvider.notifier).syncNow();

    final confirmed = await row(id);
    expect(confirmed!.syncStatus, LocalSyncStatus.synced);
    expect(confirmed.pendingMutationId, isNull);
    expect(await outboxDepth(), 0);
    expect(onlineC.read(syncEngineProvider).pendingCount, 0);
    expect(onlineC.read(syncEngineProvider).failedCount, 0);
  });

  test('edit offline then sync', () async {
    // create + sync it first so the outbox is genuinely empty
    final id = await enqueuer.create('t1', 'u1', _draft(amount: '100.00'));
    mutation.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: id,
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 11),
        ),
      }),
    );
    await container(online: true).read(syncEngineProvider.notifier).syncNow();
    expect((await row(id))!.syncStatus, LocalSyncStatus.synced);
    expect(await outboxDepth(), 0);

    await enqueuer.update('t1', id, _draft(amount: '175.50'));
    final edited = await row(id);
    expect(edited!.syncStatus, LocalSyncStatus.pendingUpdate);
    expect(edited.amount, Decimal.parse('175.50'));
    expect(await outboxDepth(), 1);

    mutation.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: id,
          tenant: 't1',
          amount: '175.50',
          updatedAt: DateTime.utc(2026, 9, 8, 12),
        ),
      }),
    );
    await container(online: true)
        .read(syncEngineProvider.notifier)
        .syncNow();

    expect((await row(id))!.syncStatus, LocalSyncStatus.synced);
    expect(await outboxDepth(), 0);
  });

  test('delete offline then sync removes the row', () async {
    container(online: false);
    final id = await enqueuer.create('t1', 'u1', _draft());
    await enqueuer.delete('t1', id);

    expect((await row(id))!.syncStatus, LocalSyncStatus.pendingDelete);

    mutation.always = const MutationResult(status: 'applied', deleted: true);
    await container(online: true)
        .read(syncEngineProvider.notifier)
        .syncNow();

    expect(await row(id), isNull);
    expect(await outboxDepth(), 0);
  });

  test('a transient network failure holds the entry, then retryFailed clears it',
      () async {
    container(online: false);
    final id = await enqueuer.create('t1', 'u1', _draft());

    // online, but the gateway fails once with a retryable (network) error —
    // the real gateway maps a SocketException to this before it reaches here.
    mutation.enqueueError(const NetworkFailure());
    final c = container(online: true);
    await c.read(syncEngineProvider.notifier).syncNow();

    // still queued, not failed-permanently
    expect((await row(id))!.syncStatus, LocalSyncStatus.pendingCreate);
    expect(await outboxDepth(), 1);

    mutation.enqueueResult(
      MutationResult.fromRpc({
        'status': 'applied',
        'deleted': false,
        'transaction': serverTxn(
          id: id,
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 13),
        ),
      }),
    );
    // force past the post-failure cool-off, as a manual pull-to-refresh does
    await c.read(syncEngineProvider.notifier).syncNow(force: true);

    expect((await row(id))!.syncStatus, LocalSyncStatus.synced);
    expect(await outboxDepth(), 0);
  });
}
