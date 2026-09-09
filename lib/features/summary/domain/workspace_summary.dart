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
  });

  final List<AccountDelta> accountDeltas;
  final Money monthIncome;
  final Money monthExpense;
  final int transactionCount;
  final DateTime fetchedAt;

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

    var income = Decimal.zero;
    var expense = Decimal.zero;
    for (final row in (raw['monthly'] as List<dynamic>? ?? const [])) {
      final m = row as Map<String, dynamic>;
      if (m['month'] != currentMonth) continue;
      final inInr = Decimal.parse(
        toInr(
          (m['total'] as num?)?.toDouble() ?? 0,
          m['currency'] as String? ?? 'INR',
        ).toString(),
      );
      if (m['type'] == 'income') {
        income += inInr;
      } else if (m['type'] == 'expense') {
        expense += inInr;
      }
    }

    final deltas = [
      for (final d in (raw['account_deltas'] as List<dynamic>? ?? const []))
        AccountDelta.fromJson(d as Map<String, dynamic>),
    ];

    final totals = raw['totals'] as Map<String, dynamic>? ?? const {};

    return WorkspaceSummary(
      accountDeltas: deltas,
      monthIncome: Money(income),
      monthExpense: Money(expense),
      transactionCount: (totals['transactions'] as num?)?.toInt() ?? 0,
      fetchedAt: fetchedAt ?? ref,
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
    );
  }
}
