import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/constants.dart';
import '../debts/debts.dart';
import '../menus/application/menu_providers.dart';
import '../recurring/application/recurring_providers.dart';
import '../recurring/domain/recurring_item.dart';
import '../reminders/application/reminders_providers.dart';
import '../reminders/domain/reminder.dart';
import '../subscriptions/subscriptions.dart';

/// What else lands on a calendar day besides transactions: things coming due.
/// The web Calendar shows the same four kinds by the same rules
/// (`src/lib/calendarEvents.ts`).
enum CalendarEventKind { reminder, subscription, recurring, emi }

class CalendarEvent {
  const CalendarEvent({
    required this.kind,
    required this.id,
    required this.day,
    required this.title,
    this.amount,
    this.currency = 'INR',
    this.income = false,
    this.paid = false,
  });

  final CalendarEventKind kind;

  /// The source row's id and the occurrence's day.
  final String id;

  /// Local midnight.
  final DateTime day;
  final String title;
  final double? amount;
  final String currency;

  /// A recurring income item (money in, not out).
  final bool income;

  /// An EMI already paid.
  final bool paid;

  /// The screen that owns the record.
  String get route => switch (kind) {
    CalendarEventKind.reminder => '/reminders',
    CalendarEventKind.subscription => '/subscriptions',
    CalendarEventKind.recurring => '/recurring',
    CalendarEventKind.emi => '/debts',
  };

  String get label => switch (kind) {
    CalendarEventKind.reminder => 'Reminder',
    CalendarEventKind.subscription => 'Renews',
    CalendarEventKind.recurring => income ? 'Income due' : 'Recurring payment',
    CalendarEventKind.emi => paid ? 'EMI paid' : 'EMI due',
  };
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] moved by [months], the day clamped to the month's last day (31 Jan +
/// 1 month = 28/29 Feb), always counted from [d] itself.
DateTime addMonthsClamped(DateTime d, int months) {
  final first = DateTime(d.year, d.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, d.day > last ? last : d.day);
}

/// The days of a series in [from, toExclusive): the k-th occurrence is
/// `step(anchor, k)` for k ≥ 0, or only [anchor] when [step] is null.
Iterable<DateTime> occurrencesIn(
  DateTime anchor,
  DateTime Function(DateTime anchor, int k)? step,
  DateTime from,
  DateTime toExclusive,
) sync* {
  final a = _day(anchor);
  if (step == null) {
    if (!a.isBefore(from) && a.isBefore(toExclusive)) yield a;
    return;
  }
  for (var k = 0; k < 10000; k++) {
    final d = _day(step(a, k));
    if (!d.isBefore(toExclusive)) return;
    if (!d.isBefore(from)) yield d;
  }
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Open reminders, every month (or quarter) they repeat. Done ones are left
/// out, and so are a debt's EMI reminders: [emisIn] shows those.
List<CalendarEvent> remindersIn(
  List<Reminder> reminders,
  DateTime from,
  DateTime toExclusive,
) => [
  for (final r in reminders)
    if (r.status != 'completed' &&
        r.extra['source'] != 'debt' &&
        r.extra['debt'] == null)
      for (final d in occurrencesIn(
        r.dueDate,
        switch (r.frequency) {
          ReminderFrequency.monthly => (a, k) => addMonthsClamped(a, k),
          ReminderFrequency.quarterly => (a, k) => addMonthsClamped(a, 3 * k),
          _ => null,
        },
        from,
        toExclusive,
      ))
        CalendarEvent(
          kind: CalendarEventKind.reminder,
          id: 'reminder-${r.id}-${_key(d)}',
          day: d,
          title: r.title.trim().isEmpty ? 'Reminder' : r.title.trim(),
          amount: r.amount?.amount.toDouble(),
          currency: r.amount?.currency ?? 'INR',
        ),
];

/// Active subscriptions, on every renewal: whole billing cycles stepped from
/// the stored renewal date ([renewalAfter]).
List<CalendarEvent> subscriptionsIn(
  List<TrackedSubscription> subs,
  DateTime from,
  DateTime toExclusive,
) => [
  for (final s in subs)
    if (s.active && s.renewal != null)
      for (final d in occurrencesIn(
        s.renewal!,
        (a, k) =>
            renewalAfter(a, s.frequency, k, intervalMonths: s.intervalMonths),
        from,
        toExclusive,
      ))
        CalendarEvent(
          kind: CalendarEventKind.subscription,
          id: 'subscription-${s.id}-${_key(d)}',
          day: d,
          title: s.name,
          amount: s.amount,
          currency: s.currency,
        ),
];

/// Active recurring items, from their next due date on.
List<CalendarEvent> recurringIn(
  List<RecurringItem> items,
  DateTime from,
  DateTime toExclusive,
) => [
  for (final r in items)
    if (r.isActive)
      for (final d in occurrencesIn(
        r.nextDueDate,
        switch (r.frequency) {
          RecurringFrequency.weekly => (a, k) => DateTime(
            a.year,
            a.month,
            a.day + 7 * k,
          ),
          RecurringFrequency.monthly => (a, k) => addMonthsClamped(a, k),
          RecurringFrequency.yearly => (a, k) => addMonthsClamped(a, 12 * k),
          RecurringFrequency.oneTime => null,
        },
        from,
        toExclusive,
      ))
        CalendarEvent(
          kind: CalendarEventKind.recurring,
          id: 'recurring-${r.id}-${_key(d)}',
          day: d,
          title: r.name,
          amount: r.amount.amount.toDouble(),
          currency: r.amount.currency,
          income: r.type == RecurringType.income,
        ),
];

/// Every EMI of every debt on its due date, paid or not.
List<CalendarEvent> emisIn(
  List<Debt> debts,
  DateTime from,
  DateTime toExclusive,
) => [
  for (final debt in debts)
    for (final i in debt.installments)
      if (i.dueDate != null &&
          !_day(i.dueDate!).isBefore(from) &&
          _day(i.dueDate!).isBefore(toExclusive))
        CalendarEvent(
          kind: CalendarEventKind.emi,
          id: 'emi-${debt.id}-${i.month}',
          day: _day(i.dueDate!),
          title: '${debt.lender} · EMI ${i.month}/${debt.duration}',
          amount: i.amount,
          currency: debt.currency,
          paid: i.paid,
        ),
];

/// [events] by day of the month (1–31), in kind order, then by title.
Map<int, List<CalendarEvent>> eventsByDay(List<CalendarEvent> events) {
  final out = <int, List<CalendarEvent>>{};
  for (final e in events) {
    (out[e.day.day] ??= []).add(e);
  }
  for (final list in out.values) {
    list.sort(
      (a, b) => a.kind.index != b.kind.index
          ? a.kind.index - b.kind.index
          : a.title.compareTo(b.title),
    );
  }
  return out;
}

/// What comes due in the month starting at [month]. A kind whose screen the
/// workspace has locked is left out (reminders by the reminders menu; the
/// rest live with expenses). A source that can't be read (offline, say) adds
/// nothing rather than failing the calendar.
final calendarEventsProvider = Provider.autoDispose
    .family<List<CalendarEvent>, DateTime>((ref, month) {
      final from = DateTime(month.year, month.month);
      final to = DateTime(month.year, month.month + 1);
      bool open(FeatureMenu m) =>
          ref.watch(menuStatusProvider(m)) != MenuStatus.locked;
      return [
        if (open(FeatureMenu.reminders))
          ...remindersIn(
            ref.watch(remindersProvider).value ?? const [],
            from,
            to,
          ),
        if (open(FeatureMenu.expenses)) ...[
          ...subscriptionsIn(
            ref.watch(trackedSubscriptionsProvider).value ?? const [],
            from,
            to,
          ),
          ...recurringIn(
            ref.watch(recurringItemsProvider).value ?? const [],
            from,
            to,
          ),
          ...emisIn(ref.watch(debtsProvider).value ?? const [], from, to),
        ],
      ];
    }, name: 'calendarEvents');
