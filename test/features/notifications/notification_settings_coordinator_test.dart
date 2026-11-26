import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/notifications/application/notification_coordinator.dart';
import 'package:finroot_mobile/features/notifications/application/notification_settings.dart';
import 'package:finroot_mobile/features/notifications/data/notification_service.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the coordinator asks the OS to schedule.
class _FakeService implements NotificationService {
  final plans = <List<PlannedNotification>>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> reconcile(List<PlannedNotification> plan) async =>
      plans.add(plan);

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> launchPayload() async => null;
}

Set<String> _kinds(List<PlannedNotification> plan) =>
    plan.map((n) => n.source.split(':').first).toSet();

void main() {
  final future = DateTime.now().add(const Duration(days: 40));
  final day = DateTime(future.year, future.month, future.day);

  testWidgets('settings switch kinds off, move the lead and the time', (
    tester,
  ) async {
    final fake = _FakeService();
    final container = ProviderContainer(
      overrides: [
        isSignedInProvider.overrideWithValue(true),
        notificationServiceProvider.overrideWithValue(fake),
        recurringItemsProvider.overrideWith(
          (ref) async => const <RecurringItem>[],
        ),
        recurringRemindersProvider.overrideWith(
          (ref) async => const <String, ReminderSetting>{},
        ),
        remindersProvider.overrideWith(
          (ref) async => [
            Reminder(
              id: 'rem-1',
              title: 'FD maturity',
              context: ReminderContext.maturity,
              dueDate: day,
              status: 'scheduled',
            ),
          ],
        ),
        trackedSubscriptionsProvider.overrideWith(
          (ref) async => [
            TrackedSubscription(
              id: 'sub-1',
              name: 'Netflix',
              amount: 649,
              currency: 'INR',
              frequency: 'monthly',
              active: true,
              renewal: day,
            ),
          ],
        ),
        insuranceProvider.overrideWith(
          (ref) async => [
            InsurancePolicy(
              id: 'pol-1',
              name: 'Health cover',
              category: 'health',
              premium: 1200,
              sumInsured: 500000,
              frequency: 'Annual',
              due: day,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationCoordinatorProvider, (_, _) {});
    final settings = container.read(notificationSettingsProvider.notifier);

    await tester.pump(const Duration(seconds: 2));
    expect(_kinds(fake.plans.last), {'reminder', 'subscription', 'insurance'});
    expect(fake.plans.last, hasLength(5)); // 1 reminder + 2 + 2

    // Turning a kind off reschedules without it.
    await settings.setSubscriptions(false);
    await tester.pump(const Duration(seconds: 2));
    expect(_kinds(fake.plans.last), {'reminder', 'insurance'});

    await settings.setReminders(false);
    await tester.pump(const Duration(seconds: 2));
    expect(_kinds(fake.plans.last), {'insurance'});

    // "On the day" leaves one premium notification; the time moves it.
    await settings.setInsuranceLead(0);
    await settings.setTime(const TimeOfDay(hour: 18, minute: 30));
    await tester.pump(const Duration(seconds: 2));
    expect(
      fake.plans.last.single.fireAt,
      DateTime(day.year, day.month, day.day, 18, 30),
    );

    // Everything off → an empty plan, which cancels what was scheduled.
    await settings.setInsurance(false);
    await tester.pump(const Duration(seconds: 2));
    expect(fake.plans.last, isEmpty);

    // And back on.
    await settings.setSubscriptions(true);
    await tester.pump(const Duration(seconds: 2));
    expect(_kinds(fake.plans.last), {'subscription'});
  });
}
