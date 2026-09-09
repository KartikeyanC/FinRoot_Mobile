import 'package:decimal/decimal.dart';

/// The category → bucket bridge, ported from the FinRoot **web** repo's
/// `src/lib/budgetBuckets.ts` (single source of truth — ADR-0008;
/// `budget_buckets_parity_test` pins it).
///
/// Budgets use a 7-jar system; transactions carry everyday categories. This map
/// is the one place that relationship lives. Unmapped categories (user-created,
/// "Other") fall back to `Needs` so spending is never silently dropped.
const Map<String, String> kCategoryToBucket = {
  'Rent': 'Needs',
  'Utilities': 'Needs',
  'Food & Dining': 'Needs',
  'Transport': 'Needs',
  'Healthcare': 'Needs',
  'Personal Care': 'Needs',
  'Shopping': 'Play',
  'Entertainment': 'Play',
  'Travel': 'Play',
  'Subscriptions': 'Play',
  'Education': 'Education',
};

/// Buckets no expense category feeds — money set aside, not spent. Derived
/// spend for them is legitimately zero and the UI should say so.
const List<String> kNonExpenseBuckets = [
  'Financial Freedom',
  'Long-Term Savings',
  'Giving',
  'Agri',
];

bool isNonExpenseBucket(String bucket) => kNonExpenseBuckets.contains(bucket);

/// Which jar an expense category belongs to. Unknown / null / empty → `Needs`.
String bucketForCategory(String? category) {
  if (category == null || category.isEmpty) return 'Needs';
  return kCategoryToBucket[category] ?? 'Needs';
}

/// Every category currently assigned to [bucket].
List<String> categoriesForBucket(String bucket) => [
  for (final e in kCategoryToBucket.entries)
    if (e.value == bucket) e.key,
];

/// The half-open period window `[start, end)` a budget row covers. Month
/// arithmetic on UTC date parts so it never shifts by timezone.
({DateTime start, DateTime end}) periodWindow(
  DateTime periodStart, [
  String period = 'monthly',
]) {
  final y = periodStart.year;
  final m = periodStart.month;
  final d = periodStart.day;
  final start = DateTime.utc(y, m, d);
  final end = switch (period) {
    'weekly' => DateTime.utc(y, m, d + 7),
    'yearly' => DateTime.utc(y + 1, m, d),
    _ => DateTime.utc(y, m + 1, d),
  };
  return (start: start, end: end);
}

/// One expense row for the pure client spend computation.
typedef BudgetSpendInput = ({
  String type,
  String? category,
  Decimal amount,
  DateTime occurredAt,
});

/// Actual spend for one budget row — real expense transactions whose category
/// maps to [bucket] and which fall inside the period. The offline equivalent of
/// `budget_spend` + [foldBudgetSpend]; pinned equal by the parity test.
Decimal deriveSpent(
  Iterable<BudgetSpendInput> transactions,
  String bucket,
  DateTime periodStart, [
  String period = 'monthly',
]) {
  final w = periodWindow(periodStart, period);
  var sum = Decimal.zero;
  for (final t in transactions) {
    if (t.type != 'expense') continue;
    if (bucketForCategory(t.category) != bucket) continue;
    final at = t.occurredAt.toUtc();
    if (at.isBefore(w.start) || !at.isBefore(w.end)) continue;
    sum += t.amount;
  }
  return sum;
}

/// First day of the month [now] falls in, as UTC midnight — the default
/// `period_start` for a monthly budget.
DateTime currentMonthStart([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime.utc(n.year, n.month);
}
