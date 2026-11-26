import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/notifications/application/notification_coordinator.dart';
import 'package:finroot_mobile/features/notifications/data/notification_service.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the coordinator asks the OS to schedule.
class _FakeService implements NotificationService {
  final plans = <List<PlannedNotification>>[];
  int cancelled = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> reconcile(List<PlannedNotification> plan) async =>
      plans.add(plan);

  @override
  Future<void> cancelAll() async => cancelled++;

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

void main() {
  // Far enough ahead that the test never depends on today's date.
  final future = DateTime.now().add(const Duration(days: 40));
  final renewal = DateTime(future.year, future.month, future.day);

  testWidgets(
    'subscriptions and premiums are scheduled, rescheduled and dropped',
    (tester) async {
      final fake = _FakeService();
      var subs = [
        TrackedSubscription(
          id: 'sub-1',
          name: 'Netflix',
          amount: 649,
          currency: 'INR',
          frequency: 'monthly',
          active: true,
          renewal: renewal,
        ),
      ];
      var policies = [
        InsurancePolicy(
          id: 'pol-1',
          name: 'Health cover',
          category: 'health',
          premium: 1200,
          sumInsured: 500000,
          frequency: 'Annual',
          due: renewal,
        ),
      ];

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
          remindersProvider.overrideWith((ref) async => const <Reminder>[]),
          trackedSubscriptionsProvider.overrideWith((ref) async => subs),
          insuranceProvider.overrideWith((ref) async => policies),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationCoordinatorProvider, (_, _) {});

      await tester.pump(const Duration(seconds: 2));
      expect(fake.plans, isNotEmpty);
      final first = fake.plans.last;
      expect(first.map((n) => n.source).toSet(), {
        'subscription:sub-1',
        'insurance:pol-1',
      });
      expect(first, hasLength(4)); // day-before + day-of, for each
      final subIds = first
          .where((n) => n.source == 'subscription:sub-1')
          .map((n) => n.id)
          .toSet();

      // Edit the renewal date → the old occurrence's ids are replaced.
      final moved = renewal.add(const Duration(days: 3));
      subs = [
        TrackedSubscription(
          id: 'sub-1',
          name: 'Netflix',
          amount: 649,
          currency: 'INR',
          frequency: 'monthly',
          active: true,
          renewal: moved,
        ),
      ];
      container.invalidate(trackedSubscriptionsProvider);
      await tester.pump(const Duration(seconds: 2));
      final second = fake.plans.last;
      final newSubIds = second
          .where((n) => n.source == 'subscription:sub-1')
          .map((n) => n.id)
          .toSet();
      expect(newSubIds, hasLength(2));
      expect(newSubIds.intersection(subIds), isEmpty);
      expect(
        second.where((n) => n.source == 'subscription:sub-1').last.fireAt,
        DateTime(moved.year, moved.month, moved.day, kNotifyHour),
      );

      // Cancel the subscription and delete the policy → nothing left.
      subs = [
        TrackedSubscription(
          id: 'sub-1',
          name: 'Netflix',
          amount: 649,
          currency: 'INR',
          frequency: 'monthly',
          active: false,
          renewal: moved,
        ),
      ];
      policies = [];
      container
        ..invalidate(trackedSubscriptionsProvider)
        ..invalidate(insuranceProvider);
      await tester.pump(const Duration(seconds: 2));
      expect(fake.plans.last, isEmpty);
    },
  );
}
