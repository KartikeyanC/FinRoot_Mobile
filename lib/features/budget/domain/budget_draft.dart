import '../../../core/money/money.dart';

/// Setting what a bucket is allocated for a period. `spent` is never a client
/// input — it is derived (`budget_spend`).
class BudgetAllocationDraft {
  const BudgetAllocationDraft({
    required this.bucket,
    required this.allocated,
    this.period = 'monthly',
    this.periodStart,
  });

  final String bucket;
  final Money allocated;
  final String period;

  /// null → the RPC defaults to the current period.
  final DateTime? periodStart;
}

abstract final class BudgetValidators {
  static String? allocated(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Enter an amount';
    final money = Money.tryParse(raw);
    if (money == null) return 'Enter a valid amount';
    if (money.isNegative) return 'An allocation cannot be negative';
    if (money > Money.parse('999999999999.99')) return 'That amount is too large';
    return null;
  }
}
