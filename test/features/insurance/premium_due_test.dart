import 'package:finroot_mobile/features/insurance/premium_due.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('premiumIntervalMonths', () {
    test('maps every web frequency; unknown counts as annual', () {
      expect(premiumIntervalMonths('Monthly'), 1);
      expect(premiumIntervalMonths('Quarterly'), 3);
      expect(premiumIntervalMonths('Half-Yearly'), 6);
      expect(premiumIntervalMonths('Annual'), 12);
      expect(premiumIntervalMonths('One-Time'), 0);
      expect(premiumIntervalMonths(null), 12);
      expect(premiumIntervalMonths('weird'), 12);
    });
  });

  group('nextPremiumDue', () {
    final today = DateTime(2026, 11, 26, 15, 30);

    test('a future due date is returned as is', () {
      expect(
        nextPremiumDue(DateTime(2026, 12, 5), 'Monthly', today),
        DateTime(2026, 12, 5),
      );
    });

    test('due today counts as the next due', () {
      expect(
        nextPremiumDue(DateTime(2026, 11, 26), 'Annual', today),
        DateTime(2026, 11, 26),
      );
    });

    test('monthly rolls forward month by month', () {
      expect(
        nextPremiumDue(DateTime(2026, 3, 10), 'Monthly', today),
        DateTime(2026, 12, 10),
      );
    });

    test('quarterly rolls forward three months at a time', () {
      expect(
        nextPremiumDue(DateTime(2026, 1, 15), 'Quarterly', today),
        DateTime(2027, 1, 15),
      );
      expect(
        nextPremiumDue(DateTime(2026, 2, 28), 'Quarterly', today),
        DateTime(2026, 11, 28),
      );
    });

    test('half-yearly rolls forward six months at a time', () {
      expect(
        nextPremiumDue(DateTime(2025, 6, 2), 'Half-Yearly', today),
        DateTime(2026, 12, 2),
      );
    });

    test('yearly rolls forward a year at a time (unknown too)', () {
      expect(
        nextPremiumDue(DateTime(2023, 8, 20), 'Annual', today),
        DateTime(2027, 8, 20),
      );
      expect(
        nextPremiumDue(DateTime(2023, 12, 2), null, today),
        DateTime(2026, 12, 2),
      );
    });

    test('month-end clamps to short months and returns to the 31st', () {
      final jan31 = DateTime(2027, 1, 31);
      expect(premiumDueAfter(jan31, 'Monthly', 1), DateTime(2027, 2, 28));
      expect(premiumDueAfter(jan31, 'Monthly', 2), DateTime(2027, 3, 31));
      expect(premiumDueAfter(jan31, 'Monthly', 3), DateTime(2027, 4, 30));
      expect(
        nextPremiumDue(DateTime(2026, 8, 31), 'Quarterly', today),
        DateTime(2026, 11, 30),
      );
      // Leap day, yearly → 28 Feb in common years, back to 29 Feb in 2028.
      final leap = DateTime(2024, 2, 29);
      expect(premiumDueAfter(leap, 'Annual', 1), DateTime(2025, 2, 28));
      expect(premiumDueAfter(leap, 'Annual', 4), DateTime(2028, 2, 29));
    });

    test('one-time: only while still to come', () {
      expect(
        nextPremiumDue(DateTime(2027, 1, 2), 'One-Time', today),
        DateTime(2027, 1, 2),
      );
      expect(nextPremiumDue(DateTime(2026, 1, 2), 'One-Time', today), isNull);
    });

    test('no due date → null', () {
      expect(nextPremiumDue(null, 'Monthly', today), isNull);
    });
  });
}
