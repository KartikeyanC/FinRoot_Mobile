import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/goals/domain/goal.dart';
import 'package:finroot_mobile/features/goals/domain/goal_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoalValidators', () {
    test('title required, ≤ 80', () {
      expect(GoalValidators.title(''), isNotNull);
      expect(GoalValidators.title('x' * 81), isNotNull);
      expect(GoalValidators.title('Emergency fund'), isNull);
    });

    test('target must be a positive amount', () {
      expect(GoalValidators.target('0'), isNotNull);
      expect(GoalValidators.target('-5'), isNotNull);
      expect(GoalValidators.target('junk'), isNotNull);
      expect(GoalValidators.target('5,00,000'), isNull);
    });

    test('contribution must be non-zero, may be negative', () {
      expect(GoalValidators.contribution('0'), isNotNull);
      expect(GoalValidators.contribution(''), isNotNull);
      expect(GoalValidators.contribution('2500'), isNull);
      expect(GoalValidators.contribution('-1000'), isNull);
    });
  });

  test('GoalContribution.fromRpc parses figures and flags', () {
    final r = GoalContribution.fromRpc({
      'applied': '2500',
      'current_amount': '10000',
      'target_amount': '10000',
      'status': 'completed',
      'capped': true,
    });
    expect(r.applied.amount, Decimal.parse('2500'));
    expect(r.currentAmount.amount, Decimal.parse('10000'));
    expect(r.reached, isTrue);
    expect(r.capped, isTrue);
  });

  group('GoalEntity progress', () {
    test('progress clamps 0..1 and completion is current >= target', () {
      final g = GoalEntity(
        id: 'g',
        title: 'Trip',
        target: Money.parse('10000'),
        current: Money.parse('4000'),
      );
      expect(g.progress, closeTo(0.4, 1e-9));
      expect(g.progressPercent, 40);
      expect(g.remaining.amount, Decimal.parse('6000'));
      expect(g.isComplete, isFalse);

      final done = GoalEntity(
        id: 'g',
        title: 'Trip',
        target: Money.parse('10000'),
        current: Money.parse('12000'),
      );
      expect(done.progress, 1.0);
      expect(done.remaining.amount, Decimal.zero);
      expect(done.isComplete, isTrue);
    });
  });
}
