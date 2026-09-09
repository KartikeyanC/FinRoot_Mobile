import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';

/// A savings goal, from the M4 cache. Progress is plain arithmetic on two
/// stored figures (`current_amount` / `target_amount`) — the `goal_contribute`
/// RPC owns the invariants (never below zero, never past target).
class GoalEntity {
  const GoalEntity({
    required this.id,
    required this.title,
    required this.target,
    required this.current,
    this.category,
    this.currency = 'INR',
    this.targetDate,
    this.status = 'active',
  });

  final String id;
  final String title;
  final Money target;
  final Money current;
  final String? category;
  final String currency;
  final DateTime? targetDate;
  final String status; // active | completed | ...

  bool get isComplete => status == 'completed' || current >= target;

  Money get remaining {
    final left = target.amount - current.amount;
    return Money(left < Decimal.zero ? Decimal.zero : left, currency);
  }

  /// 0..1.
  double get progress {
    final t = target.amount.toDouble();
    if (t <= 0) return 0;
    return (current.amount.toDouble() / t).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();
}
