import 'package:decimal/decimal.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';
import '../../accounts/domain/account_balances.dart';

/// The server-computed roll-ups the app reads instead of re-reducing the
/// ledger (M1 audit §"server stays the source of truth"). From
/// `dashboard_summary(p_tenant_id, p_months, p_tz)`.
///
/// Only the parts M8 needs are modelled: per-account movement (for balances),
/// this month's income / expense (for the Home snapshot) and the lifetime
/// transaction count. Per-currency totals are folded to INR through the fixed
/// table (`toInr`), same as the web (`src/lib/finance.ts` is the source of
/// truth — ADR-0008).
class WorkspaceSummary {
  const WorkspaceSummary({
    required this.accountDeltas,
    required this.monthIncome,
    required this.monthExpense,
    required this.transactionCount,
    required this.fetchedAt,
    this.monthlySeries = const [],
    this.categorySpend = const [],
    this.categoryIncome = const [],
  });

  final List<AccountDelta> accountDeltas;
  final Money monthIncome;
  final Money monthExpense;
  final int transactionCount;
  final DateTime fetchedAt;

  /// Income / expense per month (INR), oldest first — the full `dashboard_summary`
  /// window. Used by M15 insights for trend comparisons.
  final List<MonthPoint> monthlySeries;

  /// Current month's expense by category (INR), largest first.
  final List<CategorySpendPoint> categorySpend;

  /// Current month's income by category (INR), largest first — the web's
  /// cash-flow "In" rows.
  final List<CategorySpendPoint> categoryIncome;

  Money get monthSavings => monthIncome - monthExpense;

  static WorkspaceSummary empty() => WorkspaceSummary(
    accountDeltas: const [],
    monthIncome: Money.zero(),
    monthExpense: Money.zero(),
    transactionCount: 0,
    fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Parse the raw `dashboard_summary` JSON. [now] picks the "current month"
  /// bucket (YYYY-MM); injectable for tests.
  factory WorkspaceSummary.fromRpc(
    Map<String, dynamic> raw, {
    DateTime? now,
    DateTime? fetchedAt,
  }) {
    final ref = now ?? DateTime.now();
    final currentMonth =
        '${ref.year.toString().padLeft(4, '0')}-'
        '${ref.month.toString().padLeft(2, '0')}';

    final incomeByMonth = <String, Decimal>{};
    final expenseByMonth = <String, Decimal>{};
    for (final row in (raw['monthly'] as List<dynamic>? ?? const [])) {
      final m = row as Map<String, dynamic>;
      final month = m['month'] as String? ?? '';
      if (month.isEmpty) continue;
      final inInr = Decimal.parse(
        toInr(
          (m['total'] as num?)?.toDouble() ?? 0,
          m['currency'] as String? ?? 'INR',
        ).toString(),
      );
      if (m['type'] == 'income') {
        incomeByMonth[month] = (incomeByMonth[month] ?? Decimal.zero) + inInr;
      } else if (m['type'] == 'expense') {
        expenseByMonth[month] = (expenseByMonth[month] ?? Decimal.zero) + inInr;
      }
    }
    final months = {...incomeByMonth.keys, ...expenseByMonth.keys}.toList()
      ..sort();
    final series = [
      for (final month in months)
        MonthPoint(
          month: month,
          income: Money(incomeByMonth[month] ?? Decimal.zero),
          expense: Money(expenseByMonth[month] ?? Decimal.zero),
        ),
    ];

    // Rows carry a type; income and expense are rolled separately, as the web
    // does (`useDashboardSummary` roll()). Mixing them listed salary as spend.
    final categoryTotals = <String, ({Decimal total, int count})>{};
    final incomeTotals = <String, ({Decimal total, int count})>{};
    for (final row in (raw['categories'] as List<dynamic>? ?? const [])) {
      final c = row as Map<String, dynamic>;
      final cat = (c['category'] as String?)?.trim();
      if (cat == null || cat.isEmpty) continue;
      final bucket = switch (c['type']) {
        'income' => incomeTotals,
        'expense' || null => categoryTotals,
        _ => null,
      };
      if (bucket == null) continue;
      final inInr = Decimal.parse(
        toInr(
          (c['total'] as num?)?.toDouble() ?? 0,
          c['currency'] as String? ?? 'INR',
        ).toString(),
      );
      final prev = bucket[cat] ?? (total: Decimal.zero, count: 0);
      bucket[cat] = (
        total: prev.total + inInr,
        count: prev.count + ((c['count'] as num?)?.toInt() ?? 0),
      );
    }
    List<CategorySpendPoint> ranked(Map<String, ({Decimal total, int count})> m) => [
      for (final e in m.entries)
        if (e.value.total > Decimal.zero)
          CategorySpendPoint(
            category: e.key,
            amount: Money(e.value.total),
            count: e.value.count,
          ),
    ]..sort((a, b) => b.amount.amount.compareTo(a.amount.amount));
    final categories = ranked(categoryTotals);

    final deltas = [
      for (final d in (raw['account_deltas'] as List<dynamic>? ?? const []))
        AccountDelta.fromJson(d as Map<String, dynamic>),
    ];

    final totals = raw['totals'] as Map<String, dynamic>? ?? const {};

    return WorkspaceSummary(
      accountDeltas: deltas,
      monthIncome: Money(incomeByMonth[currentMonth] ?? Decimal.zero),
      monthExpense: Money(expenseByMonth[currentMonth] ?? Decimal.zero),
      transactionCount: (totals['transactions'] as num?)?.toInt() ?? 0,
      fetchedAt: fetchedAt ?? ref,
      monthlySeries: series,
      categorySpend: categories,
      categoryIncome: ranked(incomeTotals),
    );
  }

  Map<String, dynamic> toCache() => {
    'account_deltas': [
      for (final d in accountDeltas)
        {'account_id': d.accountId, 'delta': d.delta.toString()},
    ],
    'month_income': monthIncome.toStorageString(),
    'month_expense': monthExpense.toStorageString(),
    'transaction_count': transactionCount,
    'fetched_at': fetchedAt.toIso8601String(),
    'monthly_series': [
      for (final p in monthlySeries)
        {
          'month': p.month,
          'income': p.income.toStorageString(),
          'expense': p.expense.toStorageString(),
        },
    ],
    'category_spend': [for (final c in categorySpend) c.toJson()],
    'category_income': [for (final c in categoryIncome) c.toJson()],
  };

  factory WorkspaceSummary.fromCache(Map<String, dynamic> json) {
    return WorkspaceSummary(
      accountDeltas: [
        for (final d in (json['account_deltas'] as List<dynamic>? ?? const []))
          AccountDelta.fromJson(d as Map<String, dynamic>),
      ],
      monthIncome: Money.parse((json['month_income'] as String?) ?? '0'),
      monthExpense: Money.parse((json['month_expense'] as String?) ?? '0'),
      transactionCount: (json['transaction_count'] as num?)?.toInt() ?? 0,
      fetchedAt:
          DateTime.tryParse((json['fetched_at'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      monthlySeries: [
        for (final p in (json['monthly_series'] as List<dynamic>? ?? const []))
          MonthPoint(
            month: (p as Map<String, dynamic>)['month'] as String? ?? '',
            income: Money.parse((p['income'] as String?) ?? '0'),
            expense: Money.parse((p['expense'] as String?) ?? '0'),
          ),
      ],
      categorySpend: [
        for (final c in (json['category_spend'] as List<dynamic>? ?? const []))
          CategorySpendPoint.fromJson(c as Map<String, dynamic>),
      ],
      categoryIncome: [
        for (final c in (json['category_income'] as List<dynamic>? ?? const []))
          CategorySpendPoint.fromJson(c as Map<String, dynamic>),
      ],
    );
  }
}

/// One month's INR income / expense from `dashboard_summary.monthly`.
class MonthPoint {
  const MonthPoint({
    required this.month,
    required this.income,
    required this.expense,
  });

  /// `YYYY-MM`.
  final String month;
  final Money income;
  final Money expense;

  Money get savings => income - expense;
}

/// One category's current-month INR spend from `dashboard_summary.categories`.
class CategorySpendPoint {
  const CategorySpendPoint({
    required this.category,
    required this.amount,
    required this.count,
  });

  final String category;
  final Money amount;
  final int count;

  factory CategorySpendPoint.fromJson(Map<String, dynamic> c) => CategorySpendPoint(
    category: c['category'] as String? ?? '',
    amount: Money.parse((c['amount'] as String?) ?? '0'),
    count: (c['count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'category': category,
    'amount': amount.toStorageString(),
    'count': count,
  };
}
