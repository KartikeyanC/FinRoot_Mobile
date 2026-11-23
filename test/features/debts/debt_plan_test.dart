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
}
