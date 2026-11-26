import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/notifications/domain/due_notifications.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

TrackedSubscription _sub(
  String id,
  DateTime? renewal, {
  bool active = true,
  String frequency = 'monthly',
  int intervalMonths = 1,
}) => TrackedSubscription(
  id: id,
  name: 'Netflix',
  amount: 649,
  currency: 'INR',
  frequency: frequency,
  active: active,
  renewal: renewal,
  intervalMonths: intervalMonths,
);

InsurancePolicy _policy(String id, DateTime? due, String? frequency) =>
    InsurancePolicy(
      id: id,
      name: 'Health cover',
      category: 'health',
      premium: 1200,
      sumInsured: 500000,
      frequency: frequency,
      due: due,
    );

void main() {
  final now = DateTime(2026, 11, 26, 8); // before the 09:00 slot

  test('a renewal gets a day-before and a day-of notification at 09:00', () {
    final plan = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 12, 5))],
      now: now,
    );
    expect(plan.map((n) => n.fireAt), [
      DateTime(2026, 12, 4, kNotifyHour),
      DateTime(2026, 12, 5, kNotifyHour),
    ]);
    expect(plan.first.body, contains('tomorrow'));
    expect(plan.last.body, contains('today'));
    expect(plan.first.source, 'subscription:s1');
    expect(plan.first.id, isNot(plan.last.id));
  });

  test('a past renewal rolls forward by its cycle (custom interval)', () {
    final plan = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 5, 31), intervalMonths: 3)],
      now: now,
    );
    // 31 May + 3 → 31 Aug + 3 → 30 Nov (clamped).
    expect(plan.last.fireAt, DateTime(2026, 11, 30, kNotifyHour));
  });

  test('cancelled or dateless subscriptions are not scheduled', () {
    final plan = planDueNotifications(
      subscriptions: [
        _sub('s1', DateTime(2026, 12, 5), active: false),
        _sub('s2', null),
      ],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('due today after 09:00 → the next cycle is planned instead', () {
    final plan = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 10, 26))],
      now: DateTime(2026, 11, 26, 10),
    );
    expect(plan.map((n) => n.fireAt), [
      DateTime(2026, 12, 25, kNotifyHour),
      DateTime(2026, 12, 26, kNotifyHour),
    ]);
  });

  test('due tomorrow before 09:00 keeps both slots; after, only day-of', () {
    final early = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 11, 27))],
      now: now,
    );
    expect(early, hasLength(2));
    final late = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 11, 27))],
      now: DateTime(2026, 11, 26, 12),
    );
    expect(late.single.fireAt, DateTime(2026, 11, 27, kNotifyHour));
  });

  test('insurance premium: next due from due_date + frequency', () {
    final plan = planDueNotifications(
      policies: [_policy('p1', DateTime(2026, 2, 28), 'Quarterly')],
      now: now,
    );
    expect(plan.map((n) => n.fireAt), [
      DateTime(2026, 11, 27, kNotifyHour),
      DateTime(2026, 11, 28, kNotifyHour),
    ]);
    expect(plan.first.title, 'Insurance premium due');
    expect(plan.first.body, contains('Health cover'));
    expect(plan.first.source, 'insurance:p1');
  });

  test('past one-time premium and dateless policies are skipped', () {
    final plan = planDueNotifications(
      policies: [
        _policy('p1', DateTime(2026, 1, 2), 'One-Time'),
        _policy('p2', null, 'Monthly'),
      ],
      now: now,
    );
    expect(plan, isEmpty);
  });

  test('ids are stable across re-plans and change with the occurrence', () {
    List<int> ids(DateTime renewal) => planDueNotifications(
      subscriptions: [_sub('s1', renewal)],
      now: now,
    ).map((n) => n.id).toList();
    expect(ids(DateTime(2026, 12, 5)), ids(DateTime(2026, 12, 5)));
    expect(ids(DateTime(2026, 12, 5)), isNot(ids(DateTime(2026, 12, 6))));
  });

  test('daysBefore is configurable', () {
    final plan = planDueNotifications(
      subscriptions: [_sub('s1', DateTime(2026, 12, 5))],
      daysBefore: 3,
      now: now,
    );
    expect(plan.first.fireAt, DateTime(2026, 12, 2, kNotifyHour));
  });
}
