import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';

/// Fields the mobile goal form sets.
class GoalDraft {
  const GoalDraft({
    required this.title,
    required this.target,
    this.category,
    this.targetDate,
  });

  final String title;
  final Money target;
  final String? category;
  final DateTime? targetDate;
}

/// The outcome of a `goal_contribute` call.
class GoalContribution {
  const GoalContribution({
    required this.applied,
    required this.currentAmount,
    required this.targetAmount,
    required this.status,
    required this.capped,
  });

  final Money applied;
  final Money currentAmount;
  final Money targetAmount;
  final String status;

  /// True when the amount was trimmed to fit (overshoot, or the zero floor).
  final bool capped;

  bool get reached => status == 'completed';

  factory GoalContribution.fromRpc(Map<String, dynamic> j) => GoalContribution(
    applied: Money(_dec(j['applied'])),
    currentAmount: Money(_dec(j['current_amount'])),
    targetAmount: Money(_dec(j['target_amount'])),
    status: (j['status'] as String?) ?? 'active',
    capped: j['capped'] == true,
  );

  static Decimal _dec(Object? v) => Money.parse((v ?? 0).toString()).amount;
}

abstract final class GoalValidators {
  static String? title(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Give your goal a name';
    if (v.length > 80) return 'That name is too long';
    return null;
  }

  static String? target(String? value) {
    final money = Money.tryParse(value ?? '');
    if (money == null) return 'Enter a target amount';
    if (!money.isPositive) return 'The target must be more than zero';
    if (money > Money.parse('999999999999.99')) return 'That target is too large';
    return null;
  }

  /// Contribution amount — non-zero; may be negative (take funds back).
  static String? contribution(String? value) {
    final money = Money.tryParse(value ?? '');
    if (money == null || money.isZero) return 'Enter an amount';
    if (money.abs > Money.parse('999999999999.99')) {
      return 'That amount is too large';
    }
    return null;
  }
}
