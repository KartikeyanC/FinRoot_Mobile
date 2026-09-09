import 'dart:convert';

import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/sync/application/sync_engine.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncEngine extends SyncEngine {
  int kicks = 0;
  @override
  SyncSnapshot build() => const SyncSnapshot();
  @override
  Future<void> syncNow({bool full = false, bool force = false}) async {
    kicks++;
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  ProviderContainer container({
    String? tenantId = 't1',
    String? userId = 'u1',
    WorkspaceRole role = WorkspaceRole.owner,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentTenantIdProvider.overrideWithValue(tenantId),
        currentUserIdProvider.overrideWithValue(userId),
        currentRoleProvider.overrideWithValue(role),
        syncEngineProvider.overrideWith(_FakeSyncEngine.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<LocalTransactionRow> rowById(String id) => (db.select(
    db.localTransactions,
  )..where((t) => t.id.equals(id))).getSingle();

  test('an expense writes a pending row and a create outbox entry', () async {
    final c = container();

    final id = await c
        .read(quickAddControllerProvider)
        .submit(
          kind: QuickAddKind.expense,
          amount: Money.parse('250.50'),
          occurredAt: DateTime.utc(2026, 9, 9, 8, 30),
          category: 'Food & Dining',
          note: '  Lunch  ',
          paymentMode: 'UPI',
        );

    final row = await rowById(id);
    expect(row.syncStatus, LocalSyncStatus.pendingCreate);
    expect(row.type, 'expense');
    expect(row.amount, Money.parse('250.50').amount);
    expect(row.category, 'Food & Dining');
    expect(row.description, 'Lunch'); // trimmed
    expect(row.paymentMode, 'UPI');
    expect(row.transferToAccountId, isNull);

    final entry = await db.syncOutboxDao.byMutationId(row.pendingMutationId!);
    expect(entry!.operation, OutboxOperation.createTransaction);
    expect(entry.entityLocalId, id);
    final payload = jsonDecode(entry.payload!) as Map<String, dynamic>;
    expect(payload['amount'], '250.50');
    expect(payload['type'], 'expense');

    // the engine was nudged
    expect((c.read(syncEngineProvider.notifier) as _FakeSyncEngine).kicks, 1);
  });

  test('a transfer uses the Transfer category, no payment mode, both accounts', () async {
    final c = container();

    final id = await c
        .read(quickAddControllerProvider)
        .submit(
          kind: QuickAddKind.transfer,
          amount: Money.parse('5000.00'),
          occurredAt: DateTime.utc(2026, 9, 9),
          fromAccountId: 'acc-sbi',
          toAccountId: 'acc-cash',
        );

    final row = await rowById(id);
    expect(row.type, 'transfer');
    expect(row.category, kTransferCategory);
    expect(row.paymentMode, isNull);
    expect(row.accountId, 'acc-sbi');
    expect(row.transferToAccountId, 'acc-cash');
  });

  test('a viewer is refused with a PermissionFailure', () async {
    final c = container(role: WorkspaceRole.viewer);

    await expectLater(
      c.read(quickAddControllerProvider).submit(
        kind: QuickAddKind.expense,
        amount: Money.parse('10.00'),
        occurredAt: DateTime.utc(2026, 9, 9),
        category: 'Other',
      ),
      throwsA(isA<PermissionFailure>()),
    );

    final count = await db
        .customSelect('SELECT count(*) c FROM local_transactions')
        .getSingle();
    expect(count.read<int>('c'), 0); // nothing written
  });

  test('no session → AuthFailure', () async {
    final c = container(userId: null);

    await expectLater(
      c.read(quickAddControllerProvider).submit(
        kind: QuickAddKind.income,
        amount: Money.parse('10.00'),
        occurredAt: DateTime.utc(2026, 9, 9),
        category: 'Salary',
      ),
      throwsA(isA<AuthFailure>()),
    );
  });
}
