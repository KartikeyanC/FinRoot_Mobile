import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity with the web `isReminderDue` (`src/lib/recurringReminders.test.ts`).
/// The window is inclusive on both ends: it opens `daysBefore` days ahead of
/// the due date and closes at end of the due date itself.
DateTime _at(int y, int m, int d) => DateTime(y, m, d, 12);
ReminderSetting _on(int daysBefore) =>
    ReminderSetting(enabled: true, daysBefore: daysBefore);

void main() {
  final due = DateTime(2026, 8, 6);

  test('off when disabled', () {
    expect(
      _on(3).copyWith(enabled: false).isDue(due, today: _at(2026, 8, 6)),
      isFalse,
    );
  });

  test('off by default (a new item does not nag)', () {
    expect(ReminderSetting.off.isDue(due, today: _at(2026, 8, 6)), isFalse);
  });

  test('fires on the day the window opens', () {
    expect(_on(3).isDue(due, today: _at(2026, 8, 3)), isTrue);
  });

  test('does not fire the day before the window opens', () {
    expect(_on(3).isDue(due, today: _at(2026, 8, 2)), isFalse);
  });

  test('still fires on the due date itself', () {
    expect(_on(3).isDue(due, today: _at(2026, 8, 6)), isTrue);
  });

  test('stops after the due date passes', () {
    expect(_on(3).isDue(due, today: _at(2026, 8, 7)), isFalse);
  });

  test('daysBefore = 0 fires only on the day', () {
    expect(_on(0).isDue(due, today: _at(2026, 8, 6)), isTrue);
    expect(_on(0).isDue(due, today: _at(2026, 8, 5)), isFalse);
  });

  test('spans a month boundary', () {
    expect(
      _on(3).isDue(DateTime(2026, 8, 2), today: _at(2026, 7, 30)),
      isTrue,
    );
  });

  test('spans a year boundary', () {
    expect(
      _on(5).isDue(DateTime(2026, 1, 2), today: _at(2025, 12, 30)),
      isTrue,
    );
  });

  test('handles a leap day', () {
    expect(
      _on(2).isDue(DateTime(2028, 2, 29), today: _at(2028, 2, 27)),
      isTrue,
    );
  });

  test('fromRow reads the DB shape', () {
    final s = ReminderSetting.fromRow(
      {'enabled': true, 'days_before': 7, 'note': 'check bank'},
    );
    expect(s.enabled, isTrue);
    expect(s.daysBefore, 7);
    expect(s.note, 'check bank');
  });
}
