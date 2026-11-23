// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/income/domain/income_stream.dart';
import 'package:finroot_mobile/features/income/income_data.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/recurring/data/recurring_gateway.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _IncomeGw implements IncomeGateway {
  final inserted = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  final deleted = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async => const [];

  @override
  Future<void> insert(Map<String, dynamic> row) async => inserted.add(row);

  @override
  Future<void> update(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async => updates.add({'id': id, ...patch});

  @override
  Future<void> delete(String tenantId, String id) async => deleted.add(id);
}

class _RecurringGw implements RecurringGateway {
  final drafts = <RecurringDraft>[];

  @override
  Future<List<RecurringItem>> list(String tenantId) async => const [];

  @override
  Future<String> create(
    String tenantId,
    String userId,
    RecurringDraft draft,
  ) async {
    drafts.add(draft);
    return 'r${drafts.length}';
  }

  @override
  Future<void> update(String tenantId, String id, RecurringDraft draft) async {}

  @override
  Future<void> delete(String tenantId, String id) async {}

  @override
  Future<void> markGenerated(String id) async {}
}

Future<ProviderContainer> _container(
  _IncomeGw gw, {
  _RecurringGw? recurring,
  WorkspaceRole role = WorkspaceRole.owner,
  bool incomeOn = true,
}) async {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentUserIdProvider.overrideWithValue('u1'),
      currentRoleProvider.overrideWithValue(role),
      isOnlineProvider.overrideWithValue(true),
      incomeGatewayProvider.overrideWithValue(gw),
      recurringGatewayProvider.overrideWithValue(recurring ?? _RecurringGw()),
      effectiveMenusProvider.overrideWith(
        (ref) async => {
          for (final m in FeatureMenu.values)
            if (incomeOn || m != FeatureMenu.income) m.id,
        },
      ),
    ],
  );
  await c.read(effectiveMenusProvider.future);
  return c;
}

IncomeStream _stream(String id, int order) => IncomeStream(
  id: id,
  name: id,
  type: 'passive',
  icon: 'Coins',
  amount: 100,
  currency: 'INR',
  rate: 1,
  visible: true,
  order: order,
);

const _salary = IncomeStreamDraft(
  name: 'Acme salary',
  type: 'active',
  amount: 5000,
  currency: 'USD',
  rate: 84,
  icon: 'Briefcase',
);

void main() {
  test(
    'adding goes to the end, shown, with a matching recurring income',
    () async {
      final gw = _IncomeGw();
      final rec = _RecurringGw();
      final c = await _container(gw, recurring: rec);
      addTearDown(c.dispose);
      await c
          .read(incomeEditorProvider)
          .add(
            _salary,
            existing: [_stream('a', 1), _stream('b', 7)],
            recurring: (category: 'Salary', nextDue: DateTime(2026, 12, 1)),
          );
      final row = gw.inserted.single;
      expect(row['tenant_id'], 't1');
      expect(row['display_order'], 8);
      expect(row['is_visible'], isTrue);
      expect(row['exchange_rate_to_inr'], 84);

      final d = rec.drafts.single;
      expect(d.type, RecurringType.income);
      expect(d.category, 'Salary');
      expect(d.subtype, 'active');
      expect(d.amount.currency, 'USD');
      expect(d.fxRate, 84); // not the old hard-coded 1
      expect(d.frequency, RecurringFrequency.monthly);
      expect(d.nextDueDate, DateTime(2026, 12, 1));
    },
  );

  test('without the recurring switch, only the stream is added', () async {
    final gw = _IncomeGw();
    final rec = _RecurringGw();
    final c = await _container(gw, recurring: rec);
    addTearDown(c.dispose);
    await c.read(incomeEditorProvider).add(_salary, existing: const []);
    expect(gw.inserted.single['display_order'], 1);
    expect(rec.drafts, isEmpty);
  });

  test('edit, hide, reorder and delete write the web columns', () async {
    final gw = _IncomeGw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    final ed = c.read(incomeEditorProvider);
    final s = _stream('a', 1);
    await ed.edit(s, _salary);
    expect(gw.updates.last['currency'], 'USD');
    await ed.setVisible(s, visible: false);
    expect(gw.updates.last, {'id': 'a', 'is_visible': false});
    gw.updates.clear();
    await ed.reorder({'b': 1, 'a': 2});
    expect(gw.updates, [
      {'id': 'b', 'display_order': 1},
      {'id': 'a', 'display_order': 2},
    ]);
    await ed.delete(s);
    expect(gw.deleted, ['a']);
  });

  test('viewers and workspaces without Income cannot write', () async {
    final gw = _IncomeGw();
    final viewer = await _container(gw, role: WorkspaceRole.viewer);
    addTearDown(viewer.dispose);
    await expectLater(
      viewer.read(incomeEditorProvider).add(_salary, existing: const []),
      throwsA(isA<PermissionFailure>()),
    );
    final off = await _container(gw, incomeOn: false);
    addTearDown(off.dispose);
    await expectLater(
      off.read(incomeEditorProvider).add(_salary, existing: const []),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gw.inserted, isEmpty);
  });
}
