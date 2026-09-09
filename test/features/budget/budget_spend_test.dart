import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/budget/domain/budget_spend.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetEntity _budget(String bucket, String allocated) => BudgetEntity(
  id: bucket,
  bucket: bucket,
  allocated: Money.parse(allocated),
  period: 'monthly',
  periodStart: DateTime.utc(2026, 3),
);

BudgetSpendRow _row(String budgetId, String category, String total) =>
    BudgetSpendRow(
      budgetId: budgetId,
      category: category,
      total: Decimal.parse(total),
      count: 1,
    );

void main() {
  test('folds per-category rows into one number per bucket', () {
    final folded = foldBudgetSpend(
      [_budget('Needs', '30000')],
      [
        _row('Needs', 'Rent', '20000'),
        _row('Needs', 'Food & Dining', '3000'),
        // a Play category on the Needs budget row is not counted here
        _row('Needs', 'Entertainment', '1500'),
      ],
    );
    expect(folded.single.spent.amount, Decimal.parse('23000'));
    expect(folded.single.utilization, 77); // 23000/30000
    expect(folded.single.remaining.amount, Decimal.parse('7000'));
  });

  test('no allocation → utilization 0, remaining negative of spend', () {
    final folded = foldBudgetSpend(
      [_budget('Needs', '0')],
      [_row('Needs', 'Rent', '5000')],
    );
    expect(folded.single.utilization, 0);
    expect(folded.single.remaining.amount, Decimal.parse('-5000'));
    expect(folded.single.isOverBudget, isTrue);
  });

  test('null rows → zero spend', () {
    final folded = foldBudgetSpend([_budget('Play', '4000')], null);
    expect(folded.single.spent.amount, Decimal.zero);
    expect(folded.single.remaining.amount, Decimal.parse('4000'));
  });

  test('a non-expense bucket is flagged', () {
    final folded = foldBudgetSpend([_budget('Giving', '2000')], []);
    expect(folded.single.isNonExpense, isTrue);
  });
}
