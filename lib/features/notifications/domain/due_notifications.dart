import '../../../core/money/money_format.dart';
import '../../insurance/insurance.dart';
import '../../insurance/premium_due.dart';
import '../../subscriptions/subscriptions.dart';
import 'planned_notification.dart';

/// How many days ahead of a subscription renewal or premium due date the
/// heads-up fires (plus one on the day itself), both at [kNotifyHour].
const int kDueNoticeDaysBefore = 1;

/// Notifications for tracked subscriptions (next renewal) and insurance
/// premiums (next due from `due_date` + `payment_frequency`).
///
/// Pure and deterministic given [now]. For each active subscription with a
/// renewal date and each policy with a due date, the next occurrence whose
/// day-of slot is still ahead gets a heads-up [daysBefore] days earlier and
/// one on the day, each kept only if it is in the future. Ids derive from the
/// record id + occurrence date + slot, so re-planning replaces rather than
/// duplicates; a cancelled or deleted record simply drops out of the plan.
List<PlannedNotification> planDueNotifications({
  List<TrackedSubscription> subscriptions = const [],
  List<InsurancePolicy> policies = const [],
  int daysBefore = kDueNoticeDaysBefore,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final today = DateTime(at.year, at.month, at.day);
  final tomorrow = DateTime(at.year, at.month, at.day + 1);
  DateTime slot(DateTime d) => DateTime(d.year, d.month, d.day, kNotifyHour);

  final out = <PlannedNotification>[];

  void addPair({
    required String key,
    required DateTime due,
    required String title,
    required String Function(int days) body,
  }) {
    final slots = <int>{daysBefore, 0};
    for (final days in slots) {
      final fireAt = slot(DateTime(due.year, due.month, due.day - days));
      if (!fireAt.isAfter(at)) continue;
      out.add(
        PlannedNotification(
          id: notificationId('$key:${_ymd(due)}:d$days'),
          title: title,
          body: body(days),
          fireAt: fireAt,
          source: key,
        ),
      );
    }
  }

  for (final s in subscriptions) {
    if (!s.active || s.renewal == null) continue;
    var due = catchUpRenewal(
      s.renewal!,
      s.frequency,
      today,
      intervalMonths: s.intervalMonths,
    );
    // Today's renewal whose 09:00 slot already passed → plan the next one.
    if (!slot(due).isAfter(at)) {
      due = catchUpRenewal(
        s.renewal!,
        s.frequency,
        tomorrow,
        intervalMonths: s.intervalMonths,
      );
    }
    final amount = MoneyFormat.money(s.amount, currency: s.currency);
    addPair(
      key: 'subscription:${s.id}',
      due: due,
      title: 'Subscription renewing',
      body: (days) => '${s.name} renews ${_when(days)} — $amount.',
    );
  }

  for (final p in policies) {
    var due = nextPremiumDue(p.due, p.frequency, today);
    if (due != null && !slot(due).isAfter(at)) {
      due = nextPremiumDue(p.due, p.frequency, tomorrow);
    }
    if (due == null) continue;
    final amount = MoneyFormat.money(p.premium);
    addPair(
      key: 'insurance:${p.id}',
      due: due,
      title: 'Insurance premium due',
      body: (days) => '${p.name} premium of $amount is due ${_when(days)}.',
    );
  }

  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _when(int days) => switch (days) {
  0 => 'today',
  1 => 'tomorrow',
  _ => 'in $days days',
};
