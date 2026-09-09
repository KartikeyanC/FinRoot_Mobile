import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/budget/application/budget_editor_controller.dart';
import 'package:finroot_mobile/features/budget/data/budget_gateways.dart';
import 'package:finroot_mobile/features/budget/domain/budget_draft.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements BudgetWriteGateway {
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> setAllocation(
    String tenantId,
    BudgetAllocationDraft draft,
  ) async {
    calls.add('set:${draft.bucket}:${draft.allocated.amount}');
    return {
      'id': 'bud-${draft.bucket}',
      'tenant_id': tenantId,
      'bucket': draft.bucket,
      'allocated': draft.allocated.amount.toDouble(),
      'period': 'monthly',
      'period_start': '2026-03-01',
      'updated_at': '2026-09-09T00:00:00Z',
    };
  }

  @override
  Future<void> delete(String tenantId, String id) async => calls.add('del:$id');
}

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;

  setUp(() {
    db = AppDatabase.forTesting();
    gateway = _FakeGateway();
  });
  tearDown(() => db.close());

  ProviderContainer container({
    WorkspaceRole role = WorkspaceRole.owner,
    bool online = true,
    MenuStatus menu = MenuStatus.available,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentTenantIdProvider.overrideWithValue('t1'),
        currentRoleProvider.overrideWithValue(role),
        isOnlineProvider.overrideWithValue(online),
        budgetWriteGatewayProvider.overrideWithValue(gateway),
        menuStatusProvider(FeatureMenu.budget).overrideWithValue(menu),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('setAllocation upserts and folds the row into the cache', () async {
    await container().read(budgetEditorControllerProvider).setAllocation(
      BudgetAllocationDraft(
        bucket: 'Needs',
        allocated: Money.parse('30000'),
        periodStart: DateTime.utc(2026, 3),
      ),
    );
    expect(gateway.calls.single, startsWith('set:Needs:30000'));
    final rows = await db.select(db.localBudgets).get();
    expect(rows.single.bucket, 'Needs');
    expect(rows.single.allocated, Money.parse('30000').amount);
  });

  test('a locked budget menu refuses the write', () async {
    await expectLater(
      container(menu: MenuStatus.locked).read(budgetEditorControllerProvider)
          .setAllocation(
        BudgetAllocationDraft(bucket: 'Play', allocated: Money.parse('1000')),
      ),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gateway.calls, isEmpty);
  });

  test('offline is refused', () async {
    await expectLater(
      container(online: false).read(budgetEditorControllerProvider)
          .setAllocation(
        BudgetAllocationDraft(bucket: 'Play', allocated: Money.parse('1000')),
      ),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('a viewer is refused', () async {
    await expectLater(
      container(role: WorkspaceRole.viewer).read(budgetEditorControllerProvider)
          .setAllocation(
        BudgetAllocationDraft(bucket: 'Play', allocated: Money.parse('1000')),
      ),
      throwsA(isA<PermissionFailure>()),
    );
  });
}
