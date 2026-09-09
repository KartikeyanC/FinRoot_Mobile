/// Per-recurring-item reminder settings — the "bell" on a recurring item.
///
/// Ported from the web `src/lib/recurringReminders.ts` +
/// `src/hooks/useRecurringReminders.ts`. The DATA lives in
/// `public.recurring_reminders` (one row per item, `UNIQUE(tenant_id,
/// recurring_item_id)`); the arithmetic here is pure and unit-tested.
class ReminderSetting {
  const ReminderSetting({
    this.enabled = false,
    this.daysBefore = 3,
    this.note = '',
  });

  final bool enabled;
  final int daysBefore;
  final String note;

  static const ReminderSetting off = ReminderSetting();

  /// Choices the web offers in its "notify me N days before" picker.
  static const List<int> dayChoices = [1, 2, 3, 5, 7, 10, 14];

  ReminderSetting copyWith({bool? enabled, int? daysBefore, String? note}) =>
      ReminderSetting(
        enabled: enabled ?? this.enabled,
        daysBefore: daysBefore ?? this.daysBefore,
        note: note ?? this.note,
      );

  factory ReminderSetting.fromRow(Map<String, dynamic> r) => ReminderSetting(
    enabled: (r['enabled'] as bool?) ?? false,
    daysBefore: (r['days_before'] as num?)?.toInt() ?? 3,
    note: (r['note'] as String?) ?? '',
  );

  /// True when [today] falls inside the reminder window — from [daysBefore]
  /// ahead of [dueDate] up to and including the due date itself. Compared on
  /// calendar-date parts so it never drifts across a DST boundary (web
  /// `isReminderDue`).
  bool isDue(DateTime dueDate, {DateTime? today}) {
    if (!enabled) return false;
    final ref = today ?? DateTime.now();
    final t = DateTime(ref.year, ref.month, ref.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final windowOpens = due.subtract(Duration(days: daysBefore));
    return !t.isBefore(windowOpens) && !t.isAfter(due);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderSetting &&
      other.enabled == enabled &&
      other.daysBefore == daysBefore &&
      other.note == note;

  @override
  int get hashCode => Object.hash(enabled, daysBefore, note);
}
