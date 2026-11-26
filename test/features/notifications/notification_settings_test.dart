import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/features/notifications/application/notification_settings.dart';
import 'package:finroot_mobile/features/notifications/domain/due_notifications.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _withPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults: everything on, 1 day before, 9:00', () async {
    final container = await _withPrefs({});
    final s = container.read(notificationSettingsProvider);
    expect(s, const NotificationSettings());
    expect(s.recurring && s.reminders && s.subscriptions && s.insurance, true);
    expect(s.subscriptionLeadDays, kDueNoticeDaysBefore);
    expect(s.insuranceLeadDays, kDueNoticeDaysBefore);
    expect(s.time, const TimeOfDay(hour: 9, minute: 0));
  });

  test('works without a prefs override (this run only)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(notificationSettingsProvider.notifier);
    await c.setReminders(false);
    expect(container.read(notificationSettingsProvider).reminders, false);
  });

  test('choices persist across a new container', () async {
    final first = await _withPrefs({});
    final c = first.read(notificationSettingsProvider.notifier);
    await c.setRecurring(false);
    await c.setInsurance(false);
    await c.setSubscriptionLead(3);
    await c.setInsuranceLead(0);
    await c.setTime(const TimeOfDay(hour: 20, minute: 30));

    final prefs = await SharedPreferences.getInstance();
    final second = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);
    final s = second.read(notificationSettingsProvider);
    expect(s.recurring, false);
    expect(s.reminders, true);
    expect(s.subscriptions, true);
    expect(s.insurance, false);
    expect(s.subscriptionLeadDays, 3);
    expect(s.insuranceLeadDays, 0);
    expect(s.hour, 20);
    expect(s.minute, 30);
  });

  test('bad stored values fall back to the defaults', () async {
    final container = await _withPrefs({
      'finroot.notify.subscription_lead': 7,
      'finroot.notify.time': 99999,
    });
    final s = container.read(notificationSettingsProvider);
    expect(s.subscriptionLeadDays, kDueNoticeDaysBefore);
    expect(s.hour, kNotifyHour);
    expect(s.minute, 0);
  });

  test('lead labels', () {
    expect(kNotifyLeadOptions.map(notifyLeadLabel), [
      'On the day',
      '1 day before',
      '3 days before',
    ]);
  });

  group('planners honour lead and time', () {
    final now = DateTime(2026, 9, 9, 8);
    final sub = TrackedSubscription(
      id: 's',
      name: 'Netflix',
      amount: 649,
      currency: 'INR',
      frequency: 'monthly',
      active: true,
      renewal: DateTime(2026, 9, 20),
    );

    test('on the day only → one notification', () {
      final plan = planDueNotifications(
        subscriptions: [sub],
        daysBefore: 0,
        now: now,
      );
      expect(plan.map((n) => n.fireAt), [DateTime(2026, 9, 20, kNotifyHour)]);
    });

    test('3 days before at 18:15', () {
      final plan = planDueNotifications(
        subscriptions: [sub],
        daysBefore: 3,
        hour: 18,
        minute: 15,
        now: now,
      );
      expect(plan.map((n) => n.fireAt), [
        DateTime(2026, 9, 17, 18, 15),
        DateTime(2026, 9, 20, 18, 15),
      ]);
    });

    test('reminders fire at the chosen time', () {
      final plan = planNotifications(
        recurringItems: const [],
        reminderSettings: const {},
        reminders: [
          Reminder(
            id: 'r',
            title: 'FD maturity',
            context: ReminderContext.maturity,
            dueDate: DateTime(2026, 9, 12),
            status: 'scheduled',
          ),
        ],
        hour: 7,
        minute: 45,
        now: now,
      );
      expect(plan.single.fireAt, DateTime(2026, 9, 12, 7, 45));
    });
  });
}
