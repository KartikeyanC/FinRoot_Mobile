// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/debts/debt_editor.dart';
import 'package:finroot_mobile/features/debts/debt_plan.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gw implements DebtsGateway {
  final debts = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  final reminders = <Map<String, dynamic>>[];
  final deletedOpenFor = <String>[];
  final deletedDebts = <String>[];
  final reminderUpdates = <Map<String, dynamic>>[];
  bool refuseReminders = false;

  @override
  Future<void> updateReminder(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async => reminderUpdates.add({'id': id, ...patch});

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async => debts;

  @override
  Future<void> setInstallments(
    String tenantId,
    String debtId,
    List<Map<String, dynamic>> installments,
  ) async {}

  @override
  Future<void> insertDebt(Map<String, dynamic> row) async => debts.add(row);

  @override
  Future<void> updateDebt(
    String tenantId,
    String debtId,
    Map<String, dynamic> patch,
  ) async => updates.add({'id': debtId, ...patch});

  @override
  Future<void> deleteDebt(String tenantId, String debtId) async =>
      deletedDebts.add(debtId);

  @override
  Future<void> insertReminders(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    if (refuseReminders) {
      throw const PermissionFailure(message: 'reminders menu off');
    }
    reminders.addAll(rows);
  }

  @override
  Future<void> deleteOpenReminders(String tenantId, String debtId) async =>
      deletedOpenFor.add(debtId);

  @override
  Future<void> deleteReminders(String tenantId, List<String> ids) async =>
      reminders.removeWhere((r) => ids.contains(r['id']));
}

Future<ProviderContainer> _container(
  _Gw gw, {
  bool reminders = true,
  bool online = true,
}) async {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      isOnlineProvider.overrideWithValue(online),
      debtsGatewayProvider.overrideWithValue(gw),
      effectiveMenusProvider.overrideWith(
        (ref) async => {
          for (final m in FeatureMenu.values)
            if (reminders || m != FeatureMenu.reminders) m.id,
        },
      ),
    ],
  );
  await c.read(effectiveMenusProvider.future);
  return c;
}

DebtDraft _draft({
  String lender = 'HDFC',
  double total = 30000,
  int months = 3,
  String category = 'Other',
  String notes = '',
}) => DebtDraft(
  lender: lender,
  category: category,
  total: total,
  months: months,
  firstDue: DateTime(2026, 12, 5),
  notes: notes,
);

Debt _debt(List<Map<String, dynamic>> installments) => Debt.fromRow({
  'id': 'd1',
  'lender': 'HDFC',
  'category': 'Other',
  'currency': 'INR',
  'total_amount': 30000,
  'monthly': 10000,
  'duration': 3,
  'first_due_date': '2026-12-05',
  'installments': installments,
});

void main() {
  test('adding saves the debt with an EMI reminder each', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    await c.read(debtEditorProvider).add(_draft());
    expect(gw.debts, hasLength(1));
    expect(gw.reminders, hasLength(3));
    final inst = gw.debts.single['installments'] as List;
    expect(
      [for (final i in inst) (i as Map)['reminderId']],
      [for (final r in gw.reminders) r['id']],
    );
  });

  test('reminders refused or switched off: the debt is still saved', () async {
    final gw = _Gw()..refuseReminders = true;
    final c = await _container(gw);
    addTearDown(c.dispose);
    await c.read(debtEditorProvider).add(_draft());
    expect(gw.debts, hasLength(1));
    expect(gw.reminders, isEmpty);
    expect(
      (gw.debts.single['installments'] as List).first,
      isNot(contains('reminderId')),
    );

    final gw2 = _Gw();
    final c2 = await _container(gw2, reminders: false);
    addTearDown(c2.dispose);
    await c2.read(debtEditorProvider).add(_draft());
    expect(gw2.reminders, isEmpty);
    expect(gw2.debts, hasLength(1));
  });

  test('offline: nothing is written', () async {
    final gw = _Gw();
    final c = await _container(gw, online: false);
    addTearDown(c.dispose);
    await expectLater(
      c.read(debtEditorProvider).add(_draft()),
      throwsA(isA<NetworkFailure>()),
    );
    expect(gw.debts, isEmpty);
  });

  test(
    'editing the schedule rebuilds EMIs and reminders while none is paid',
    () async {
      final gw = _Gw();
      final c = await _container(gw);
      addTearDown(c.dispose);
      final existing = _debt(
        buildInstallments(30000, 3, DateTime(2026, 12, 5)),
      );
      await c
          .read(debtEditorProvider)
          .edit(existing, _draft(total: 36000, months: 6));
      expect(gw.deletedOpenFor, ['d1']);
      expect(gw.reminders, hasLength(6));
      final u = gw.updates.single;
      expect(u['total_amount'], 36000);
      expect(u['duration'], 6);
      expect(u['installments'] as List, hasLength(6));
    },
  );

  test('a notes-only edit keeps the schedule and its reminders', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    final existing = _debt(buildInstallments(30000, 3, DateTime(2026, 12, 5)));
    await c
        .read(debtEditorProvider)
        .edit(existing, _draft(category: 'Rent', notes: 'Note'));
    expect(gw.deletedOpenFor, isEmpty);
    expect(gw.reminders, isEmpty);
    expect(gw.updates.single.containsKey('installments'), isFalse);
    expect(gw.updates.single['category'], 'Rent');
  });

  test(
    'once an EMI is paid the schedule is fixed, but a rename works',
    () async {
      final gw = _Gw();
      final c = await _container(gw);
      addTearDown(c.dispose);
      final inst = buildInstallments(30000, 3, DateTime(2026, 12, 5));
      inst[0] = {...inst[0], 'status': 'paid', 'reminderId': 'old-1'};
      final existing = _debt(inst);
      await expectLater(
        c.read(debtEditorProvider).edit(existing, _draft(total: 40000)),
        throwsA(isA<ValidationFailure>()),
      );
      await c
          .read(debtEditorProvider)
          .edit(existing, _draft(lender: 'HDFC Bank'));
      // The paid EMI keeps its reminder; the two open ones get fresh ones.
      expect(gw.reminders, hasLength(2));
      expect(gw.reminders.first['title'], 'HDFC Bank · EMI 2/3');
      final saved = gw.updates.single['installments'] as List;
      expect((saved[0] as Map)['reminderId'], 'old-1');
    },
  );

  test('deleting removes the open reminders, then the debt', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    await c.read(debtEditorProvider).delete(_debt(const []));
    expect(gw.deletedOpenFor, ['d1']);
    expect(gw.deletedDebts, ['d1']);
  });

  test('one EMI: new amount and paid, with its reminder', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    final debt = _debt([
      {
        'month': 1,
        'dueDate': '2026-12-05',
        'amount': 10000,
        'status': 'pending',
        'reminderId': 'r1',
      },
      {
        'month': 2,
        'dueDate': '2027-01-05',
        'amount': 10000,
        'status': 'pending',
      },
      {
        'month': 3,
        'dueDate': '2027-02-05',
        'amount': 10000,
        'status': 'pending',
      },
    ]);
    await c
        .read(debtEditorProvider)
        .updateInstallment(debt, 1, amount: 12000, paid: true);
    final patch = gw.updates.single;
    final inst = patch['installments'] as List;
    expect((inst[0] as Map)['amount'], 12000);
    expect((inst[0] as Map)['status'], 'paid');
    expect((inst[0] as Map)['reminderId'], 'r1'); // unknown keys survive
    expect(patch['total_amount'], 32000);
    expect(patch['monthly'], 10000);
    expect(gw.reminderUpdates.single, {
      'id': 'r1',
      'amount': 12000,
      'status': 'completed',
    });
  });

  test('a new debt can start with EMIs already paid', () async {
    final gw = _Gw();
    final c = await _container(gw);
    addTearDown(c.dispose);
    await c
        .read(debtEditorProvider)
        .add(
          DebtDraft(
            lender: 'Bajaj',
            category: 'Other',
            total: 30000,
            months: 3,
            firstDue: DateTime(2026, 9, 5),
            paidBefore: 2,
          ),
        );
    final inst = gw.debts.single['installments'] as List;
    expect(
      [for (final i in inst) (i as Map)['status']],
      ['paid', 'paid', 'pending'],
    );
    expect(gw.reminders, hasLength(1));
  });
}
