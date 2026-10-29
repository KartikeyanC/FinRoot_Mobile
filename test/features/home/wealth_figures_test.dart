import 'package:finroot_mobile/features/home/domain/wealth_figures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('month-on-month matches the web (null without a previous month)', () {
    expect(monthOnMonth([]), isNull);
    expect(monthOnMonth([500]), isNull);
    expect(monthOnMonth([0, 500]), isNull);
    expect(monthOnMonth([400, 500]), 25);
    expect(monthOnMonth([500, 400]), -20);
  });

  test('savings rate rounds like the web', () {
    expect(savingsRate(0, 100), 0);
    expect(savingsRate(1000, 600), 40);
    expect(savingsRate(3, 2), 33);
  });

  test('health score: savings 40 + goals 30 + debt 30', () {
    // 30%+ savings, every goal done, no debt → 100.
    expect(
      healthScore(savings: 1, savingsRate: 35, goalProgress: [1, 1], assets: 100, liabilities: 0).score,
      100,
    );
    // Nothing saved, no goals (counts as half), debt equal to assets → 15.
    final weak = healthScore(savings: -1, savingsRate: 0, goalProgress: [], assets: 100, liabilities: 100);
    expect(weak.score, 15);
    expect(weak.verdict, 'needs work');
    expect(weak.checks.where((c) => c.ok), isEmpty);
    // Debt with no assets counts as fully indebted.
    expect(
      healthScore(savings: 0, savingsRate: 0, goalProgress: [], assets: 0, liabilities: 5).score,
      15,
    );
  });

  test('investment series is a running total, largest holding first', () {
    expect(cumulativeHoldings([100, 0, 300, -5, 200]), [300, 500, 600]);
  });
}
