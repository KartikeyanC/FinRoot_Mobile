import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:flutter_test/flutter_test.dart';

InsurancePolicy _policy({DateTime? due, String? frequency}) => InsurancePolicy(
  id: 'p1',
  name: 'Term plan',
  category: 'life',
  premium: 1000,
  sumInsured: 100000,
  frequency: frequency,
  due: due,
);

void main() {
  final today = DateTime(2026, 11, 26, 15, 40);

  test('a past annual premium rolls forward instead of reading overdue', () {
    final d = PremiumDisplay.of(
      _policy(due: DateTime(2024, 3, 10), frequency: 'Annual'),
      today,
    );
    expect(d.next, DateTime(2027, 3, 10));
    expect(d.ended, isFalse);
    expect(d.daysAway, greaterThan(15));
    expect(d.dueSoon, isFalse);
  });

  test('a past monthly premium shows the next month, due soon', () {
    final d = PremiumDisplay.of(
      _policy(due: DateTime(2026, 1, 30), frequency: 'Monthly'),
      today,
    );
    expect(d.next, DateTime(2026, 11, 30));
    expect(d.daysAway, 4);
    expect(d.dueSoon, isTrue);
  });

  test('a premium due today is today, not tomorrow', () {
    final d = PremiumDisplay.of(
      _policy(due: DateTime(2025, 11, 26), frequency: 'Annual'),
      today,
    );
    expect(d.next, DateTime(2026, 11, 26));
    expect(d.daysAway, 0);
  });

  test('a past one-time premium is paid, not overdue', () {
    final d = PremiumDisplay.of(
      _policy(due: DateTime(2025, 6, 2), frequency: 'One-Time'),
      today,
    );
    expect(d.next, isNull);
    expect(d.ended, isTrue);
    expect(d.dueSoon, isFalse);
  });

  test('a future one-time premium is still shown', () {
    final d = PremiumDisplay.of(
      _policy(due: DateTime(2027, 1, 5), frequency: 'One-Time'),
      today,
    );
    expect(d.next, DateTime(2027, 1, 5));
    expect(d.ended, isFalse);
  });

  test('no due date shows nothing', () {
    final d = PremiumDisplay.of(_policy(), today);
    expect(d.next, isNull);
    expect(d.ended, isFalse);
    expect(d.dueSoon, isFalse);
  });

  test('the stored due date is untouched', () {
    final p = _policy(due: DateTime(2024, 3, 10), frequency: 'Annual');
    PremiumDisplay.of(p, today);
    expect(p.due, DateTime(2024, 3, 10));
  });
}
