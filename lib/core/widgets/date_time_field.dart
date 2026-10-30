import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';

/// The one date + time control for every create/edit form.
///
/// Renders a "Date" field and a "Time" field side by side (stacked when text
/// is scaled up or the space is narrow), each a tappable 12dp-radius field that
/// opens [showDatePicker] / [showTimePicker], and reports the combined
/// [DateTime] through [onChanged].
///
/// There is deliberately no clear / empty state: pickers can only replace the
/// value. Forms start it at [DateTime.now]. If a caller somehow passes a null
/// [value], both fields show a placeholder and [requiredMessage] is shown, so
/// the person can see why they cannot submit.
///
/// With [showTime] false only the date field is rendered (goal targets,
/// renewal dates and other inherently date-only values) — still required.
class DateTimeField extends StatelessWidget {
  const DateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.showTime = true,
    this.dateLabel = 'Date',
    this.timeLabel = 'Time',
    this.requiredMessage = 'Date and time are required',
    this.enabled = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  /// Earliest / latest selectable moment. A pick that lands after [lastDate]
  /// (today, a time later than now) is clamped to it.
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool showTime;
  final String dateLabel;
  final String timeLabel;
  final String requiredMessage;
  final bool enabled;

  static final DateFormat _dateFormat = DateFormat('d MMM yyyy');

  /// "3:42 PM" with a plain space (newer ICU data uses a narrow no-break one).
  static String formatTime(DateTime when) => DateFormat.jm()
      .format(when.toLocal())
      .replaceAll(RegExp('[  ]'), ' ');

  /// "30 Oct, 3:42 pm" — the compact form used on rows and details.
  static String format(DateTime when, {DateTime? now}) {
    final d = when.toLocal();
    final ref = now ?? DateTime.now();
    final date = d.year == ref.year
        ? DateFormat('d MMM').format(d)
        : DateFormat('d MMM yyyy').format(d);
    return '$date, ${formatTime(d).toLowerCase()}';
  }

  DateTime _clamp(DateTime v) {
    var out = v;
    final last = lastDate;
    if (last != null && out.isAfter(last)) out = last;
    final first = firstDate;
    if (first != null && out.isBefore(first)) out = first;
    return out;
  }

  Future<void> _pickDate(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = value ?? now;
    final first = firstDate ?? DateTime(now.year - 5);
    final last = lastDate ?? DateTime(now.year + 10);
    final initial = current.isBefore(first)
        ? first
        : (current.isAfter(last) ? last : current);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(last.year, last.month, last.day),
    );
    if (picked == null) return;
    onChanged(
      _clamp(
        DateTime(
          picked.year,
          picked.month,
          picked.day,
          showTime ? current.hour : 0,
          showTime ? current.minute : 0,
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final current = value ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;
    onChanged(
      _clamp(
        DateTime(
          current.year,
          current.month,
          current.day,
          picked.hour,
          picked.minute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    final dateField = _Part(
      label: dateLabel,
      icon: Icons.event_outlined,
      text: v == null ? 'Select date' : _dateFormat.format(v.toLocal()),
      isEmpty: v == null,
      onTap: enabled ? () => _pickDate(context) : null,
      fieldKey: const ValueKey('date_time_field.date'),
    );
    final timeField = _Part(
      label: timeLabel,
      icon: Icons.schedule_rounded,
      text: v == null ? 'Select time' : formatTime(v),
      isEmpty: v == null,
      onTap: enabled ? () => _pickTime(context) : null,
      fieldKey: const ValueKey('date_time_field.time'),
    );

    final stack = MediaQuery.textScalerOf(context).scale(16) > 19.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showTime)
          dateField
        else if (stack) ...[
          dateField,
          const SizedBox(height: AppSpacing.lg),
          timeField,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: dateField),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 9, child: timeField),
            ],
          ),
        if (v == null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              showTime ? requiredMessage : 'Date is required',
              key: const ValueKey('date_time_field.error'),
              style: AppTypography.label.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _Part extends StatelessWidget {
  const _Part({
    required this.label,
    required this.icon,
    required this.text,
    required this.isEmpty,
    required this.onTap,
    required this.fieldKey,
  });

  final String label;
  final IconData icon;
  final String text;
  final bool isEmpty;
  final VoidCallback? onTap;
  final Key fieldKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: AppTypography.label.copyWith(color: palette.muted),
          ),
        ),
        Semantics(
          button: true,
          label: '$label, $text',
          excludeSemantics: true,
          child: InkWell(
            key: fieldKey,
            onTap: onTap,
            borderRadius: AppRadius.field,
            child: InputDecorator(
              decoration: InputDecoration(prefixIcon: Icon(icon)),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isEmpty ? palette.muted : null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
