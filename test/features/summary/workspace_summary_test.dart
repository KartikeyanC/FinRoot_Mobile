import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw = <String, dynamic>{
    'monthly': [
      {'month': '2026-09', 'type': 'income', 'currency': 'INR', 'total': 80000},
      {'month': '2026-09', 'type': 'expense', 'currency': 'INR', 'total': 30000},
      {'month': '2026-09', 'type': 'income', 'currency': 'USD', 'total': 100},
      // a prior month — ignored for the "current month" figures
      {'month': '2026-08', 'type': 'expense', 'currency': 'INR', 'total': 99999},
    ],
    'account_deltas': [
      {'account_id': 'sbi', 'delta': '12000.50'},
      {'account_id': 'cash', 'delta': '-2500'},
    ],
    'categories': [
      {'category': 'Food & Dining', 'currency': 'INR', 'total': 18000, 'count': 22},
      {'category': 'Transport', 'currency': 'INR', 'total': 7000, 'count': 8},
    ],
    'totals': {'transactions': 412},
  };

  test('fromRpc folds the current month to INR and reads deltas', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 9, 15));

    // 80,000 INR + 100 USD * 83.5 = 88,350
    expect(s.monthIncome.amount, Decimal.parse('88350'));
    expect(s.monthExpense.amount, Decimal.parse('30000'));
    expect(s.monthSavings.amount, Decimal.parse('58350'));
    expect(s.transactionCount, 412);
    expect(s.accountDeltas, hasLength(2));
    expect(
      s.accountDeltas.firstWhere((d) => d.accountId == 'sbi').delta,
      Decimal.parse('12000.50'),
    );
  });

  test('a different current month yields zero income / expense', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 10, 2));
    expect(s.monthIncome.amount, Decimal.zero);
    expect(s.monthExpense.amount, Decimal.zero);
    // deltas are all-history, still present
    expect(s.accountDeltas, hasLength(2));
  });

  test('toCache / fromCache round-trips', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 9, 15));
    final back = WorkspaceSummary.fromCache(s.toCache());

    expect(back.monthIncome.amount, s.monthIncome.amount);
    expect(back.monthExpense.amount, s.monthExpense.amount);
    expect(back.transactionCount, s.transactionCount);
    expect(back.accountDeltas.map((d) => '${d.accountId}:${d.delta}'), [
      'sbi:12000.5',
      'cash:-2500',
    ]);
  });

  test('empty() is inert', () {
    final s = WorkspaceSummary.empty();
    expect(s.accountDeltas, isEmpty);
    expect(s.monthIncome.amount, Decimal.zero);
    expect(s.transactionCount, 0);
    expect(s.monthlySeries, isEmpty);
    expect(s.categorySpend, isEmpty);
  });

  test('fromRpc builds the monthly series (INR, oldest first)', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 9, 15));
    expect(s.monthlySeries.map((p) => p.month), ['2026-08', '2026-09']);
    final aug = s.monthlySeries.first;
    expect(aug.expense.amount, Decimal.parse('99999'));
    expect(aug.income.amount, Decimal.zero);
    final sep = s.monthlySeries.last;
    expect(sep.income.amount, Decimal.parse('88350')); // 80k + 100 USD
    expect(sep.expense.amount, Decimal.parse('30000'));
  });

  test('fromRpc reads current-month categories, largest first, INR', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 9, 15));
    expect(s.categorySpend.map((c) => c.category), ['Food & Dining', 'Transport']);
    expect(s.categorySpend.first.amount.amount, Decimal.parse('18000'));
    expect(s.categorySpend.first.count, 22);
  });

  test('toCache / fromCache round-trips the series and categories', () {
    final s = WorkspaceSummary.fromRpc(raw, now: DateTime(2026, 9, 15));
    final back = WorkspaceSummary.fromCache(s.toCache());
    expect(back.monthlySeries.map((p) => p.month), ['2026-08', '2026-09']);
    expect(back.monthlySeries.last.income.amount, Decimal.parse('88350'));
    expect(back.categorySpend.first.category, 'Food & Dining');
    expect(back.categorySpend.first.count, 22);
  });
}
