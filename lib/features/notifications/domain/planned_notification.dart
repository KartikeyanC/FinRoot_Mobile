import '../../recurring/domain/recurring_item.dart';
import '../../recurring/domain/reminder_setting.dart';
import '../../reminders/domain/reminder.dart';

/// One notification the app wants the OS to fire at [fireAt] (local time).
///
/// [id] is a stable 31-bit int derived from the source row id + occurrence, so
/// re-planning the same state produces the same request and the scheduler can
/// cancel-all-then-reschedule without duplicates.
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.source,
  });

  final int id;
  final String title;
  final String body;
  final DateTime fireAt;

  /// `recurring:<uuid>` or `reminder:<uuid>` — for logging / debugging.
  final String source;

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.fireAt == fireAt;

  @override
  int get hashCode => Object.hash(id, title, body, fireAt);

  @override
  String toString() => 'PlannedNotification($id, "$title", $fireAt, $source)';
}

/// Stable non-negative 31-bit hash for a notification key.
int notificationId(String key) => key.hashCode & 0x7fffffff;

/// The hour of day (local) at which day-of notifications fire. Reminders don't
/// carry a time, so we pick a sensible morning slot.
const int kNotifyHour = 9;

/// Compute every notification the app should currently have scheduled.
///
/// Pure and deterministic given [now]. Inputs:
/// - [recurringItems] — active templates (income + expense);
/// - [reminderSettings] — itemId → bell setting (`recurring_reminders`);
/// - [reminders] — standalone reminders, already rolled forward.
///
/// Rules (mirroring the web's in-app "due" surfaces):
/// - a recurring item with an **enabled** bell → one notification, `daysBefore`
///   ahead of `nextDueDate` at [kNotifyHour], only if that instant is future;
/// - a non-completed standalone reminder → one notification on its due date at
///   [kNotifyHour], only if future.
///
/// [hour] / [minute] move the firing time (Settings → Notifications); they
/// default to [kNotifyHour]:00.
List<PlannedNotification> planNotifications({
  required List<RecurringItem> recurringItems,
  required Map<String, ReminderSetting> reminderSettings,
  required List<Reminder> reminders,
  DateTime? now,
  int hour = kNotifyHour,
  int minute = 0,
}) {
  final ref = now ?? DateTime.now();
  final out = <PlannedNotification>[];
  final timeOfDay = Duration(hours: hour, minutes: minute);

  for (final item in recurringItems) {
    if (!item.isActive) continue;
    final setting = reminderSettings[item.id];
    if (setting == null || !setting.enabled) continue;

    final due = DateTime(
      item.nextDueDate.year,
      item.nextDueDate.month,
      item.nextDueDate.day,
    );
    final fireAt = due
        .subtract(Duration(days: setting.daysBefore))
        .add(timeOfDay);
    if (!fireAt.isAfter(ref)) continue;

    final verb = item.isIncome ? 'expected' : 'due';
    final note = setting.note.trim();
    out.add(PlannedNotification(
      id: notificationId('recurring:${item.id}:${_ymd(due)}'),
      title: item.isIncome ? 'Income coming up' : 'Payment coming up',
      body: note.isNotEmpty
          ? '${item.name} — ${item.amount.format()} $verb ${_duePhrase(setting.daysBefore)}. $note'
          : '${item.name} — ${item.amount.format()} $verb ${_duePhrase(setting.daysBefore)}.',
      fireAt: fireAt,
      source: 'recurring:${item.id}',
    ));
  }

  for (final r in reminders) {
    if (r.isCompleted) continue;
    final due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day)
        .add(timeOfDay);
    if (!due.isAfter(ref)) continue;
    out.add(PlannedNotification(
      id: notificationId('reminder:${r.id}:${_ymd(r.dueDate)}'),
      title: r.title.trim().isEmpty ? 'Reminder' : r.title.trim(),
      body: reminderMessage(r, now: ref),
      fireAt: due,
      source: 'reminder:${r.id}',
    ));
  }

  out.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return out;
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _duePhrase(int daysBefore) => switch (daysBefore) {
  0 => 'today',
  1 => 'tomorrow',
  _ => 'in $daysBefore days',
};
