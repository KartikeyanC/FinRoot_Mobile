import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/constants.dart';
import '../../budget/application/budget_providers.dart';
import '../../budget/domain/budget_spend.dart';
import '../../goals/application/goals_providers.dart';
import '../../goals/domain/goal.dart';
import '../../menus/application/menu_providers.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../recurring/domain/recurring_item.dart';
import '../../summary/application/summary_providers.dart';
import '../domain/insight.dart';
import '../domain/insight_engine.dart';

/// The workspace's derived insights (M15). Rule-based, on device — reads the
/// same `dashboard_summary` roll-up, budgets, goals and recurring items the
/// rest of the app already loads. Empty until there is something to say.
final insightsProvider = Provider<List<Insight>>((ref) {
  final summary = ref.watch(workspaceSummaryProvider).value;
  if (summary == null) return const [];

  final budgets = ref.watch(menuAvailableProvider(FeatureMenu.budget))
      ? ref.watch(budgetsWithSpendProvider).value ?? const <BudgetWithSpend>[]
      : const <BudgetWithSpend>[];

  final goals = ref.watch(menuAvailableProvider(FeatureMenu.goals))
      ? ref.watch(goalsProvider).value ?? const <GoalEntity>[]
      : const <GoalEntity>[];

  final recurring =
      ref.watch(recurringItemsProvider).value ?? const <RecurringItem>[];

  return buildInsights(
    summary: summary,
    budgets: budgets,
    goals: goals,
    recurring: recurring,
  );
}, name: 'insights');

/// The top few insights, for the Home card.
final homeInsightsProvider = Provider<List<Insight>>(
  (ref) => ref.watch(insightsProvider).take(3).toList(),
  name: 'homeInsights',
);
