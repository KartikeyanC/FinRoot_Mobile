import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity with the web `bumpDate` (`src/hooks/useRecurring.test.ts`) — the
/// mobile port must advance a due date exactly as the web client and the
/// server's `mark_recurring_generated` do.
DateTime _d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('bumpDate — weekly', () {
    test('adds seven days', () {
      expect(bumpDate(_d(2026, 3, 10), RecurringFrequency.weekly),
          _d(2026, 3, 17));
    });
    test('crosses a month boundary', () {
      expect(bumpDate(_d(2026, 3, 28), RecurringFrequency.weekly),
          _d(2026, 4, 4));
    });
    test('crosses a year boundary', () {
      expect(bumpDate(_d(2026, 12, 28), RecurringFrequency.weekly),
          _d(2027, 1, 4));
    });
  });

  group('bumpDate — monthly', () {
    test('keeps the day of month', () {
      expect(bumpDate(_d(2026, 3, 15), RecurringFrequency.monthly),
          _d(2026, 4, 15));
    });
    test('clamps Jan 31 to Feb 28 in a non-leap year', () {
      expect(bumpDate(_d(2026, 1, 31), RecurringFrequency.monthly),
          _d(2026, 2, 28));
    });
    test('clamps Jan 31 to Feb 29 in a leap year', () {
      expect(bumpDate(_d(2024, 1, 31), RecurringFrequency.monthly),
          _d(2024, 2, 29));
    });
    test('clamps May 31 to Jun 30', () {
      expect(bumpDate(_d(2026, 5, 31), RecurringFrequency.monthly),
          _d(2026, 6, 30));
    });
    test('Dec rolls into Jan of next year', () {
      expect(bumpDate(_d(2026, 12, 15), RecurringFrequency.monthly),
          _d(2027, 1, 15));
      expect(bumpDate(_d(2026, 12, 31), RecurringFrequency.monthly),
          _d(2027, 1, 31));
    });
  });

  group('bumpDate — yearly', () {
    test('advances the year, keeping month and day', () {
      expect(bumpDate(_d(2026, 7, 4), RecurringFrequency.yearly),
          _d(2027, 7, 4));
    });
    test('clamps Feb 29 to Feb 28 when the next year is not a leap year', () {
      expect(bumpDate(_d(2024, 2, 29), RecurringFrequency.yearly),
          _d(2025, 2, 28));
    });
  });

  test('one-time does not advance', () {
    expect(bumpDate(_d(2026, 3, 10), RecurringFrequency.oneTime),
        _d(2026, 3, 10));
  });

  test('RecurringFrequency wire values match the DB CHECK', () {
    expect(RecurringFrequency.monthly.wire, 'monthly');
    expect(RecurringFrequency.weekly.wire, 'weekly');
    expect(RecurringFrequency.yearly.wire, 'yearly');
    expect(RecurringFrequency.oneTime.wire, 'one-time');
  });
}
