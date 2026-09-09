import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/budget/domain/budget_spend.dart';
import 'package:finroot_mobile/features/goals/domain/goal.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:finroot_mobile/features/insights/domain/insight_engine.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 15, 12);
Money _m(String v) => Money(Decimal.parse(v));
MonthPoint _mp(String month, String income, String expense) =>
    MonthPoint(month: month, income: _m(income), expense: _m(expense));

WorkspaceSummary _summary({
  String monthIncome = '0',
  String monthExpense = '0',
  List<MonthPoint> series = const [],
  List<CategorySpendPoint> categories = const [],
  int txns = 200,
}) => WorkspaceSummary(
  accountDeltas: const [],
  monthIncome: _m(monthIncome),
  monthExpense: _m(monthExpense),
  transactionCount: txns,
  fetchedAt: _now,
  monthlySeries: series,
  categorySpend: categories,
);

BudgetWithSpend _budget(String bucket, String allocated, String spent) {
  final alloc = _m(allocated);
  final sp = _m(spent);
  return BudgetWithSpend(
    budget: BudgetEntity(
      id: bucket,
      bucket: bucket,
      allocated: alloc,
      period: 'monthly',
      periodStart: DateTime(2026, 9),
    ),
    spent: sp,
    utilization: alloc.isPositive
        ? (sp.amount.toDouble() / alloc.amount.toDouble() * 100).round()
        : 0,
    remaining: Money(alloc.amount - sp.amount),
  );
}

GoalEntity _goal(String title, String current, String target) => GoalEntity(
  id: title,
  title: title,
  current: _m(current),
  target: _m(target),
);

RecurringItem _rec(String name, String amount, int daysOut) => RecurringItem(
  id: name,
  type: RecurringType.expense,
  name: name,
  category: 'Rent',
  amount: _m(amount),
  frequency: RecurringFrequency.monthly,
  nextDueDate: _now.add(Duration(days: daysOut)),
  isActive: true,
);

List<Insight> _run({
  WorkspaceSummary? summary,
  List<BudgetWithSpend> budgets = const [],
  List<GoalEntity> goals = const [],
  List<RecurringItem> recurring = const [],
}) => buildInsights(
  summary: summary ?? _summary(),
  budgets: budgets,
  goals: goals,
  recurring: recurring,
  now: _now,
);

Insight? _byId(List<Insight> list, String id) =>
    list.where((i) => i.id == id).firstOrNull;

void main() {
  test('nothing to say -> a single onboarding insight', () {
    final out = _run(summary: _summary(txns: 1));
    expect(out, hasLength(1));
    expect(out.single.id, 'onboarding');
  });

  group('savings rate', () {
    test('negative savings is an alert', () {
      final out = _run(
        summary: _summary(monthIncome: '40000', monthExpense: '52000'),
      );
      expect(_byId(out, 'savings-negative')!.kind, InsightKind.alert);
    });

    test('above the recent average reads positive', () {
      final out = _run(
        summary: _summary(
          monthIncome: '100000',
          monthExpense: '60000', // 40% saved
          series: [
            _mp('2026-07', '100000', '80000'), // 20%
            _mp('2026-08', '100000', '82000'), // 18%
            _mp('2026-09', '100000', '60000'),
          ],
        ),
      );
      final i = _byId(out, 'savings-vs-average')!;
      expect(i.kind, InsightKind.positive);
      expect(i.title, contains('40%'));
    });

    test('below the recent average reads as a watch', () {
      final out = _run(
        summary: _summary(
          monthIncome: '100000',
          monthExpense: '92000', // 8%
          series: [
            _mp('2026-07', '100000', '70000'),
            _mp('2026-08', '100000', '72000'),
            _mp('2026-09', '100000', '92000'),
          ],
        ),
      );
      expect(_byId(out, 'savings-vs-average')!.kind, InsightKind.watch);
    });
  });

  test('spend up sharply vs last month is a watch', () {
    final out = _run(
      summary: _summary(
        monthIncome: '100000',
        monthExpense: '60000',
        series: [
          _mp('2026-08', '100000', '40000'),
          _mp('2026-09', '100000', '60000'), // +50%
        ],
      ),
    );
    final i = _byId(out, 'spend-vs-last-month')!;
    expect(i.kind, InsightKind.watch);
    expect(i.title, contains('50%'));
  });

  test('top category + concentration', () {
    final out = _run(
      summary: _summary(
        monthExpense: '30000',
        categories: [
          CategorySpendPoint(category: 'Food & Dining', amount: _m('20000'), count: 25),
          CategorySpendPoint(category: 'Transport', amount: _m('10000'), count: 6),
        ],
      ),
    );
    expect(_byId(out, 'top-category')!.title, contains('Food & Dining'));
    // 20k / 30k = 67% -> concentration fires
    expect(_byId(out, 'category-concentration')!.kind, InsightKind.watch);
  });

  group('budget', () {
    test('two jars over budget -> one alert', () {
      final out = _run(budgets: [
        _budget('Needs', '20000', '24000'),
        _budget('Play', '5000', '6000'),
      ]);
      final i = _byId(out, 'budget-over-many')!;
      expect(i.kind, InsightKind.alert);
      expect(i.route, '/budget');
    });

    test('one jar tight with days left -> watch', () {
      // 15 Sep -> 15 days left, well over the 3-day floor
      final out = _run(budgets: [_budget('Needs', '20000', '18000')]); // 90%
      final i = _byId(out, 'budget-tight')!;
      expect(i.kind, InsightKind.watch);
      expect(i.title, contains('90%'));
    });
  });

  test('a fully funded goal is celebrated', () {
    final out = _run(goals: [_goal('Emergency Fund', '100000', '100000')]);
    expect(_byId(out, 'goal-complete-Emergency Fund')!.kind, InsightKind.positive);
  });

  test('recurring bills due this week are summed', () {
    final out = _run(recurring: [
      _rec('Rent', '25000', 3),
      _rec('Phone', '999', 6),
      _rec('Later', '500', 20), // outside the 7-day window
    ]);
    final i = _byId(out, 'recurring-due-week')!;
    expect(i.detail, contains('2 items'));
    expect(i.route, '/recurring');
  });

  test('alerts sort ahead of watches ahead of the rest', () {
    final out = _run(
      summary: _summary(
        monthIncome: '40000',
        monthExpense: '52000',
        categories: [
          CategorySpendPoint(category: 'Rent', amount: _m('52000'), count: 1),
        ],
      ),
      budgets: [_budget('Needs', '20000', '25000')],
    );
    expect(out.first.kind, InsightKind.alert);
  });
}
