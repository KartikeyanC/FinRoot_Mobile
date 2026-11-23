import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_providers.dart';
import '../../debts/debts.dart';
import '../../goals/application/goals_providers.dart';
import '../../insights/application/insights_providers.dart';
import '../../insights/domain/insight.dart';
import '../../investments/application/investments_providers.dart';
import '../../investments/domain/live_price.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../recurring/domain/recurring_item.dart';
import '../../summary/application/summary_providers.dart';
import '../../summary/domain/workspace_summary.dart';
import '../domain/wealth_figures.dart';

/// Every figure the web-style Home cards draw, worked out once so each card
/// can be placed anywhere in the person's order.
class HomeWealth {
  const HomeWealth({
    required this.summary,
    required this.income,
    required this.expense,
    required this.rate,
    required this.assets,
    required this.liabilities,
    required this.investedCurrent,
    required this.invested,
    required this.investmentSeries,
    required this.incomeMom,
    required this.health,
    required this.upcoming,
    required this.hasAccounts,
    required this.topInsight,
  });

  final WorkspaceSummary summary;
  final double income;
  final double expense;
  final int rate;
  final double assets;
  final double liabilities;
  final double investedCurrent;
  final double invested;
  final List<double> investmentSeries;
  final double? incomeMom;
  final HealthScore health;

  /// Active expense bills, soonest first.
  final List<RecurringItem> upcoming;
  final bool hasAccounts;
  final Insight? topInsight;

  double get savings => income - expense;
  double get netWorth => assets - liabilities;
  bool get hasActivity => income > 0 || expense > 0;

  /// The bill for the heads-up pill: the next one, when it is due within a
  /// week (or overdue).
  RecurringItem? nudgeBill(DateTime now) {
    if (upcoming.isEmpty) return null;
    final next = upcoming.first;
    return next.daysUntilDue(now: now) <= 7 ? next : null;
  }
}

final homeWealthProvider = Provider<HomeWealth>((ref) {
  final summary =
      ref.watch(workspaceSummaryProvider).value ?? WorkspaceSummary.empty();
  final cash = ref.watch(totalBalanceProvider).amount.toDouble();
  final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
  final portfolio = ref.watch(portfolioSummaryProvider);
  final investments = ref.watch(investmentsProvider).value ?? const [];
  final livePrices =
      ref.watch(holdingPricesProvider).value ?? const <String, double>{};
  final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
  final goals = ref.watch(goalsProvider).value ?? const [];
  final bills =
      ref.watch(recurringItemsProvider).value ?? const <RecurringItem>[];
  final insights = ref.watch(homeInsightsProvider);

  final income = summary.monthIncome.amount.toDouble();
  final expense = summary.monthExpense.amount.toDouble();
  final savings = income - expense;
  final rate = savingsRate(income, expense);
  final invCurrent = portfolio.current.amount.toDouble();
  final assets = cash + invCurrent;
  final liabilities = debts.fold<double>(
    0,
    (s, d) => s + math.max(0, d.remaining),
  );
  final series = summary.monthlySeries.length > 6
      ? summary.monthlySeries.sublist(summary.monthlySeries.length - 6)
      : summary.monthlySeries;

  return HomeWealth(
    summary: summary,
    income: income,
    expense: expense,
    rate: rate,
    assets: assets,
    liabilities: liabilities,
    investedCurrent: invCurrent,
    invested: portfolio.invested.amount.toDouble(),
    investmentSeries: cumulativeHoldings([
      for (final r in investments) effectiveCurrent(r, livePrices),
    ]),
    incomeMom: monthOnMonth([
      for (final p in series) p.income.amount.toDouble(),
    ]),
    health: healthScore(
      savings: savings,
      savingsRate: rate,
      goalProgress: [
        for (final g in goals)
          if (g.target.amount.toDouble() > 0)
            (g.current.amount.toDouble() / g.target.amount.toDouble())
                .clamp(0, 1)
                .toDouble(),
      ],
      assets: assets,
      liabilities: liabilities,
    ),
    upcoming: [
      for (final b in bills)
        if (b.isActive && b.type == RecurringType.expense) b,
    ]..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate)),
    hasAccounts: accounts.isNotEmpty,
    topInsight: insights.isEmpty ? null : insights.first,
  );
}, name: 'homeWealth');
