import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../budget/domain/budget_spend.dart';
import '../../goals/domain/goal.dart';
import '../../recurring/domain/recurring_item.dart';
import '../../summary/domain/workspace_summary.dart';
import 'insight.dart';

/// Build the workspace's insights from the data the app already has. Pure and
/// deterministic given [now]. Rule-based — see [Insight].
List<Insight> buildInsights({
  required WorkspaceSummary summary,
  List<BudgetWithSpend> budgets = const [],
  List<GoalEntity> goals = const [],
  List<RecurringItem> recurring = const [],
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  final out = <Insight>[];

  out.addAll(_savingsRate(summary, ref));
  out.addAll(_spendVsLastMonth(summary, ref));
  out.addAll(_topCategory(summary));
  out.addAll(_concentration(summary));
  out.addAll(_budgetPressure(budgets, ref));
  out.addAll(_goalProgress(goals));
  out.addAll(_upcomingRecurring(recurring, ref));

  if (out.isEmpty) {
    out.add(const Insight(
      id: 'onboarding',
      kind: InsightKind.neutral,
      title: 'Insights build as you log',
      detail:
          'Record a few weeks of income and expenses and patterns — your '
          'savings rate, category trends, budget pressure — show up here.',
    ));
  }

  out.sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return _severity(b.kind).compareTo(_severity(a.kind));
  });
  return out;
}

int _severity(InsightKind k) => switch (k) {
  InsightKind.alert => 3,
  InsightKind.watch => 2,
  InsightKind.positive => 1,
  InsightKind.neutral => 0,
};

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

int _daysLeftInMonth(DateTime now) =>
    DateTime(now.year, now.month + 1, 0).day - now.day;

int _pctChange(Money from, Money to) {
  final f = from.amount.toDouble();
  if (f == 0) return 0;
  return ((to.amount.toDouble() - f) / f * 100).round();
}

// ---------------------------------------------------------------------------

List<Insight> _savingsRate(WorkspaceSummary s, DateTime now) {
  if (!s.monthIncome.isPositive) return const [];
  final rate = (s.monthSavings.amount.toDouble() /
          s.monthIncome.amount.toDouble() *
          100)
      .round();

  if (rate < 0) {
    return [
      Insight(
        id: 'savings-negative',
        kind: InsightKind.alert,
        title: 'You spent more than you earned this month',
        detail:
            'Expenses (${s.monthExpense.formatShort()}) came in above income '
            '(${s.monthIncome.formatShort()}).',
        priority: 40,
      ),
    ];
  }

  final currentKey = _monthKey(now);
  final priorRates = <int>[];
  for (final m in s.monthlySeries) {
    if (m.month == currentKey || !m.income.isPositive) continue;
    priorRates.add(
      (m.savings.amount.toDouble() / m.income.amount.toDouble() * 100).round(),
    );
  }

  if (priorRates.isNotEmpty) {
    final avg = (priorRates.reduce((a, b) => a + b) / priorRates.length).round();
    final gap = rate - avg;
    if (gap.abs() >= 5) {
      return [
        Insight(
          id: 'savings-vs-average',
          kind: gap >= 0 ? InsightKind.positive : InsightKind.watch,
          title: "You've saved $rate% of your income this month",
          detail: gap >= 0
              ? 'That is above your recent average of $avg%.'
              : 'That is below your recent average of $avg%.',
          priority: gap >= 0 ? 15 : 22,
        ),
      ];
    }
  }

  return [
    Insight(
      id: 'savings-rate',
      kind: rate >= 20 ? InsightKind.positive : InsightKind.neutral,
      title: "You've saved $rate% of your income this month",
      detail: '${s.monthSavings.formatShort()} set aside so far.',
      priority: 8,
    ),
  ];
}

List<Insight> _spendVsLastMonth(WorkspaceSummary s, DateTime now) {
  final currentKey = _monthKey(now);
  final prev = DateTime(now.year, now.month - 1);
  final prevKey = _monthKey(prev);

  MonthPoint? cur, last;
  for (final m in s.monthlySeries) {
    if (m.month == currentKey) cur = m;
    if (m.month == prevKey) last = m;
  }
  if (cur == null || last == null) return const [];
  if (!last.expense.isPositive || !cur.expense.isPositive) return const [];

  final change = _pctChange(last.expense, cur.expense);
  if (change.abs() < 15) return const [];
  final up = change > 0;
  return [
    Insight(
      id: 'spend-vs-last-month',
      kind: up ? InsightKind.watch : InsightKind.positive,
      title: up
          ? 'Spending is up ${change.abs()}% vs last month'
          : 'Spending is down ${change.abs()}% vs last month',
      detail:
          '${last.expense.formatShort()} last month → '
          '${cur.expense.formatShort()} so far this month.',
      priority: up ? 18 : 12,
    ),
  ];
}

List<Insight> _topCategory(WorkspaceSummary s) {
  if (s.categorySpend.isEmpty) return const [];
  final top = s.categorySpend.first;
  if (!top.amount.isPositive) return const [];
  return [
    Insight(
      id: 'top-category',
      kind: InsightKind.neutral,
      title: '${top.category} is your biggest category this month',
      detail:
          '${top.amount.formatShort()} across ${top.count} '
          '${top.count == 1 ? 'transaction' : 'transactions'}.',
      priority: 5,
    ),
  ];
}

List<Insight> _concentration(WorkspaceSummary s) {
  if (s.categorySpend.length < 2) return const [];
  var total = Decimal.zero;
  for (final c in s.categorySpend) {
    total += c.amount.amount;
  }
  if (total <= Decimal.zero) return const [];
  final top = s.categorySpend.first;
  final share = top.amount.amount.toDouble() / total.toDouble();
  if (share < 0.45) return const [];
  return [
    Insight(
      id: 'category-concentration',
      kind: InsightKind.watch,
      title:
          '${(share * 100).round()}% of this month\'s spending went to '
          '${top.category}',
      detail:
          '${top.amount.formatShort()} of ${Money(total).formatShort()} total.',
      priority: 16,
    ),
  ];
}

List<Insight> _budgetPressure(List<BudgetWithSpend> budgets, DateTime now) {
  final relevant = budgets
      .where((b) => !b.isNonExpense && b.budget.allocated.amount > Decimal.zero)
      .toList();
  if (relevant.isEmpty) return const [];

  final over = relevant.where((b) => b.isOverBudget).toList();
  if (over.length >= 2) {
    return [
      Insight(
        id: 'budget-over-many',
        kind: InsightKind.alert,
        title: '${over.length} budget jars are over for this month',
        detail: over.map((b) => b.budget.bucket).take(3).join(', ') +
            (over.length > 3 ? '…' : '.'),
        route: '/budget',
        priority: 35,
      ),
    ];
  }
  if (over.length == 1) {
    final b = over.first;
    return [
      Insight(
        id: 'budget-over-one',
        kind: InsightKind.alert,
        title: 'Your ${b.budget.bucket} jar is over budget',
        detail:
            '${b.spent.formatShort()} spent of ${b.budget.allocated.formatShort()} '
            'allocated.',
        route: '/budget',
        priority: 32,
      ),
    ];
  }

  final daysLeft = _daysLeftInMonth(now);
  if (daysLeft < 3) return const [];
  final tight = relevant.where((b) => b.utilization >= 85).toList()
    ..sort((a, b) => b.utilization.compareTo(a.utilization));
  if (tight.isEmpty) return const [];
  final b = tight.first;
  return [
    Insight(
      id: 'budget-tight',
      kind: InsightKind.watch,
      title:
          'Your ${b.budget.bucket} jar is at ${b.utilization}% with '
          '$daysLeft days left',
      detail: '${b.remaining.formatShort()} left for the rest of the month.',
      route: '/budget',
      priority: 20,
    ),
  ];
}

List<Insight> _goalProgress(List<GoalEntity> goals) {
  final active = goals.where((g) => g.status == 'active').toList();
  if (active.isEmpty) return const [];

  final done = active.where((g) => g.progressPercent >= 100).toList();
  if (done.isNotEmpty) {
    final g = done.first;
    return [
      Insight(
        id: 'goal-complete-${g.id}',
        kind: InsightKind.positive,
        title: "You've fully funded ${g.title}",
        detail: '${g.target.formatShort()} reached — time to lock it in.',
        route: '/goals',
        priority: 14,
      ),
    ];
  }

  final inProgress = active.where((g) => g.progress > 0 && g.progress < 1).toList()
    ..sort((a, b) => b.progress.compareTo(a.progress));
  if (inProgress.isEmpty) return const [];
  final g = inProgress.first;
  if (g.progressPercent < 50) return const [];
  return [
    Insight(
      id: 'goal-progress-${g.id}',
      kind: InsightKind.neutral,
      title: '${g.title} is ${g.progressPercent}% funded',
      detail: '${g.remaining.formatShort()} to go.',
      route: '/goals',
      priority: 6,
    ),
  ];
}

List<Insight> _upcomingRecurring(List<RecurringItem> items, DateTime now) {
  var total = Money.zero();
  var count = 0;
  for (final i in items) {
    if (!i.isActive || i.type != RecurringType.expense) continue;
    final days = i.daysUntilDue(now: now);
    if (days < 0 || days > 7) continue;
    total = total + Money(i.amount.amount);
    count++;
  }
  if (count == 0 || !total.isPositive) return const [];
  return [
    Insight(
      id: 'recurring-due-week',
      kind: InsightKind.watch,
      title: '${total.formatShort()} in recurring bills due this week',
      detail: '$count ${count == 1 ? 'item' : 'items'} coming up in the next 7 days.',
      route: '/recurring',
      priority: 24,
    ),
  ];
}
