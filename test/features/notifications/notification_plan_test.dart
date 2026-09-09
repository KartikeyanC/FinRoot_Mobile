import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringItem _item(String id, DateTime due, {bool active = true}) =>
    RecurringItem(
      id: id,
      type: RecurringType.expense,
      name: 'Rent',
      category: 'Rent',
      amount: Money.parse('25000'),
      frequency: RecurringFrequency.monthly,
      nextDueDate: due,
      isActive: active,
    );

Reminder _reminder(String id, DateTime due, {String status = 'scheduled'}) =>
    Reminder(
      id: id,
      title: 'FD maturity',
      context: ReminderContext.maturity,
      dueDate: due,
      status: status,
    );

void main() {
  final now = DateTime(2026, 9, 9, 8);

  test('no bell → no recurring notification', () {
    final plan = planNotifications(
      recurringItems: [_item('a', DateTime(2026, 9, 20))],
      reminderSettings: const {},
      reminders: const [],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('an enabled bell schedules one notification daysBefore ahead at 09:00', () {
    final plan = planNotifications(
      recurringItems: [_item('a', DateTime(2026, 9, 20))],
      reminderSettings: const {
        'a': ReminderSetting(enabled: true, daysBefore: 4),
      },
      reminders: const [],
      now: now,
    );
    expect(plan, hasLength(1));
    expect(plan.single.fireAt, DateTime(2026, 9, 16, kNotifyHour));
    expect(plan.single.source, 'recurring:a');
    expect(plan.single.body, contains('Rent'));
  });

  test('a bell whose window already opened is not scheduled (in the past)', () {
    final plan = planNotifications(
      recurringItems: [_item('a', DateTime(2026, 9, 10))],
      reminderSettings: const {
        'a': ReminderSetting(enabled: true, daysBefore: 4),
      },
      reminders: const [],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('an inactive item is skipped even with a bell', () {
    final plan = planNotifications(
      recurringItems: [_item('a', DateTime(2026, 9, 20), active: false)],
      reminderSettings: const {
        'a': ReminderSetting(enabled: true, daysBefore: 4),
      },
      reminders: const [],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('a future reminder schedules one on its due date; a completed one does not', () {
    final plan = planNotifications(
      recurringItems: const [],
      reminderSettings: const {},
      reminders: [
        _reminder('r1', DateTime(2026, 9, 25)),
        _reminder('r2', DateTime(2026, 9, 25), status: 'completed'),
      ],
      now: now,
    );
    expect(plan, hasLength(1));
    expect(plan.single.source, 'reminder:r1');
    expect(plan.single.fireAt, DateTime(2026, 9, 25, kNotifyHour));
  });

  test('output is sorted by fire time and ids are stable', () {
    List<PlannedNotification> run() => planNotifications(
      recurringItems: [_item('a', DateTime(2026, 9, 20))],
      reminderSettings: const {
        'a': ReminderSetting(enabled: true, daysBefore: 4),
      },
      reminders: [_reminder('r1', DateTime(2026, 9, 12))],
      now: now,
    );
    final first = run();
    final second = run();
    expect(first.map((n) => n.id).toList(),
        second.map((n) => n.id).toList());
    expect(first.first.fireAt.isBefore(first.last.fireAt), isTrue);
    expect(first.every((n) => n.id >= 0), isTrue);
  });
}
