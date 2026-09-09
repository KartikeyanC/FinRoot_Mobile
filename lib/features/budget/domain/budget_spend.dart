import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import 'budget_buckets.dart';

/// A budget bucket for one period, straight from the M4 cache.
class BudgetEntity {
  const BudgetEntity({
    required this.id,
    required this.bucket,
    required this.allocated,
    required this.period,
    required this.periodStart,
  });

  final String id;
  final String bucket;
  final Money allocated;
  final String period; // weekly | monthly | yearly
  final DateTime periodStart;
}

/// One row of `budget_spend`: a budget's expense total in a single category.
class BudgetSpendRow {
  const BudgetSpendRow({
    required this.budgetId,
    required this.category,
    required this.total,
    required this.count,
  });

  final String budgetId;
  final String category;
  final Decimal total;
  final int count;

  factory BudgetSpendRow.fromJson(Map<String, dynamic> j) => BudgetSpendRow(
    budgetId: j['budget_id'] as String,
    category: (j['category'] as String?) ?? '',
    total: Decimal.parse((j['total'] ?? 0).toString()),
    count: ((j['count'] as num?) ?? 0).toInt(),
  );
}

/// A budget with its derived spend folded on — ported from web
/// `foldBudgetSpend` (`src/hooks/useBudgetSpend.ts`). The category → bucket map
/// stays client-side (`budget_buckets.dart`); the server does the windowing and
/// summing, this decides which jar each category falls in.
class BudgetWithSpend {
  const BudgetWithSpend({
    required this.budget,
    required this.spent,
    required this.utilization,
    required this.remaining,
  });

  final BudgetEntity budget;
  final Money spent;
  final int utilization;
  final Money remaining;

  bool get isOverBudget => remaining.amount < Decimal.zero;
  bool get isNonExpense => isNonExpenseBucket(budget.bucket);
}

List<BudgetWithSpend> foldBudgetSpend(
  List<BudgetEntity> budgets,
  List<BudgetSpendRow>? rows,
) {
  final byBudget = <String, List<BudgetSpendRow>>{};
  for (final r in rows ?? const <BudgetSpendRow>[]) {
    (byBudget[r.budgetId] ??= []).add(r);
  }

  return [
    for (final b in budgets)
      () {
        var spent = Decimal.zero;
        for (final r in byBudget[b.id] ?? const <BudgetSpendRow>[]) {
          if (bucketForCategory(r.category) == b.bucket) spent += r.total;
        }
        final allocated = b.allocated.amount;
        return BudgetWithSpend(
          budget: b,
          spent: Money(spent),
          utilization: allocated > Decimal.zero
              ? (spent.toDouble() / allocated.toDouble() * 100).round()
              : 0,
          remaining: Money(allocated - spent),
        );
      }(),
  ];
}
