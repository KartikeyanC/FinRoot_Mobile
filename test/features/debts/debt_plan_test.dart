// Dates are spelled out in full to read like the schedule.
// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/features/debts/debt_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the EMI schedule matches the web's buildInstallments", () {
    // Expected values printed by the web's own code (TZ Asia/Kolkata):
    // 31 Jan + 1 month overflows to 3 Mar, as JavaScript's setMonth does.
    expect(buildInstallments(10000, 3, DateTime(2026, 1, 31)), [
      {
        'month': 1,
        'dueDate': '2026-01-31',
        'amount': 3333.33,
        'status': 'pending',
      },
      {
        'month': 2,
        'dueDate': '2026-03-03',
        'amount': 3333.33,
        'status': 'pending',
      },
      {
        'month': 3,
        'dueDate': '2026-03-31',
        'amount': 3333.34,
        'status': 'pending',
      },
    ]);
    final twelve = buildInstallments(30000, 12, DateTime(2026, 12, 5));
    expect(twelve, hasLength(12));
    expect(twelve[10]['dueDate'], '2027-10-05');
    expect(twelve.last['dueDate'], '2027-11-05');
    expect(twelve.last['amount'], 2500);
    expect(buildInstallments(0, 12, DateTime(2026)), isEmpty);
    expect(buildInstallments(100, 0, DateTime(2026)), isEmpty);
  });

  test('monthly is total over months, unrounded', () {
    expect(computeMonthly(10000, 3), closeTo(3333.333, 0.001));
    expect(computeMonthly(0, 3), 0);
  });

  test('a new debt writes the row and one reminder per EMI', () {
    final d = DebtDraft(
      lender: ' HDFC Bank ',
      category: 'Other',
      total: 30000,
      months: 3,
      firstDue: DateTime(2026, 12, 5),
      notes: 'Car loan',
    );
    final plan = planNewDebt(
      tenantId: 't1',
      d: d,
      withReminders: true,
      now: DateTime.utc(2026, 11, 23, 10),
      debtId: 'debt-1',
    );
    expect(plan.debt['id'], 'debt-1');
    expect(plan.debt['tenant_id'], 't1');
    expect(plan.debt['lender'], 'HDFC Bank');
    expect(plan.debt['total_amount'], 30000);
    expect(plan.debt['duration'], 3);
    expect(plan.debt['monthly'], 10000);
    expect(plan.debt['first_due_date'], '2026-12-05');
    expect(plan.debt['notes'], 'Car loan');

    final inst = plan.debt['installments'] as List;
    expect(plan.reminders, hasLength(3));
    final r = plan.reminders[1];
    expect(r['title'], 'HDFC Bank · EMI 2/3');
    expect(r['due_date'], '2027-01-05');
    expect(r['source'], 'debt');
    expect(r['source_id'], 'debt-1');
    expect(r['context'], 'fixed_due');
    expect(r['frequency'], 'one_time');
    expect(r['grace'], '3d');
    expect(r['debt'], {
      'debtId': 'debt-1',
      'month': 2,
      'totalMonths': 3,
      'lender': 'HDFC Bank',
    });
    // Each installment points at its reminder, as on the web.
    expect((inst[1] as Map)['reminderId'], r['id']);

    final bare = planNewDebt(
      tenantId: 't1',
      d: d,
      withReminders: false,
      now: DateTime.utc(2026, 11, 23),
    );
    expect(bare.reminders, isEmpty);
    expect(
      (bare.debt['installments'] as List).first,
      isNot(contains('reminderId')),
    );
  });

  test('validation', () {
    expect(DebtValidators.lender(''), isNotNull);
    expect(DebtValidators.lender('HDFC'), isNull);
    expect(DebtValidators.total('0'), isNotNull);
    expect(DebtValidators.total('30,000'), isNull);
    expect(DebtValidators.months('0'), isNotNull);
    expect(DebtValidators.months('361'), isNotNull);
    expect(DebtValidators.months('12'), isNull);
  });

  group('a loan that started before it was added', () {
    final sept5 = DateTime(2026, 9, 5);

    test('counts the EMIs already due', () {
      // A September loan added on 25 November: Sep 5 and Oct 5 are past,
      // Nov 5 too; Dec 5 is not.
      expect(emisDueBefore(sept5, 12, DateTime(2026, 11, 25)), 3);
      expect(emisDueBefore(sept5, 12, DateTime(2026, 11, 5)), 2);
      expect(emisDueBefore(sept5, 2, DateTime(2027, 6, 1)), 2);
      expect(
        emisDueBefore(DateTime(2026, 12, 5), 12, DateTime(2026, 11, 25)),
        0,
      );
    });

    test('back-filled EMIs are paid on their own due dates', () {
      final list = backfillPaid(buildInstallments(30000, 3, sept5), 2);
      expect(list[0]['status'], 'paid');
      expect(list[0]['backfilled'], true);
      expect(
        list[0]['paidAt'],
        DateTime(2026, 9, 5, 12).toUtc().toIso8601String(),
      );
      expect(list[1]['status'], 'paid');
      expect(list[2]['status'], 'pending');
      expect(list[2].containsKey('paidAt'), isFalse);
    });

    test('no reminder is scheduled for an EMI already paid', () {
      final plan = planNewDebt(
        tenantId: 't1',
        d: DebtDraft(
          lender: 'Bajaj',
          category: 'Other',
          total: 30000,
          months: 3,
          firstDue: sept5,
          paidBefore: 2,
        ),
        withReminders: true,
        now: DateTime(2026, 11, 25),
      );
      expect(plan.reminders, hasLength(1));
      final inst = plan.debt['installments'] as List;
      expect((inst[0] as Map).containsKey('reminderId'), isFalse);
      expect((inst[2] as Map)['reminderId'], plan.reminders.single['id']);
    });
  });

  group('editing one EMI', () {
    final base = buildInstallments(30000, 3, DateTime(2026, 9, 5));

    test('a new amount moves the total; monthly is the next unpaid EMI', () {
      final list = withInstallmentAmount(base, 1, 12500.456);
      expect(list[0]['amount'], 12500.46);
      expect(list[1]['amount'], 10000);
      final t = debtTotals(list);
      expect(t.total, 32500.46);
      expect(t.monthly, 12500.46);

      final paid = withInstallmentPaid(
        list,
        1,
        paid: true,
        now: DateTime.utc(2026, 9, 6),
      );
      expect(debtTotals(paid).monthly, 10000);
    });

    test('paid and back to unpaid', () {
      final paid = withInstallmentPaid(
        backfillPaid(base, 1),
        2,
        paid: true,
        now: DateTime.utc(2026, 10, 6, 8),
      );
      expect(paid[1]['status'], 'paid');
      expect(paid[1]['paidAt'], '2026-10-06T08:00:00.000Z');

      final undone = withInstallmentPaid(
        paid,
        1,
        paid: false,
        now: DateTime.utc(2026, 11),
      );
      expect(undone[0]['status'], 'pending');
      expect(undone[0].containsKey('paidAt'), isFalse);
      expect(undone[0].containsKey('backfilled'), isFalse);
      // Marking a paid EMI paid again keeps its first date.
      final again = withInstallmentPaid(
        paid,
        2,
        paid: true,
        now: DateTime.utc(2027),
      );
      expect(again[1]['paidAt'], '2026-10-06T08:00:00.000Z');
    });

    test('all paid: monthly is the last EMI', () {
      final all = backfillPaid(withInstallmentAmount(base, 3, 9000), 3);
      expect(debtTotals(all), (total: 29000.0, monthly: 9000.0));
    });
  });
}
