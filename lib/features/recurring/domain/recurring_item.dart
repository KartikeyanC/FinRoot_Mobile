import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../domain/constants.dart';

/// `recurring_items.type` — an income or an expense template.
enum RecurringType {
  income,
  expense;

  String get wire => name;
  static RecurringType fromWire(String v) =>
      RecurringType.values.firstWhere((t) => t.name == v,
          orElse: () => RecurringType.expense);
}

/// `recurring_items.frequency` CHECK. `oneTime` is the wire value `one-time`.
enum RecurringFrequency {
  monthly('monthly'),
  weekly('weekly'),
  yearly('yearly'),
  oneTime('one-time');

  const RecurringFrequency(this.wire);
  final String wire;

  String get label => switch (this) {
    RecurringFrequency.monthly => 'Monthly',
    RecurringFrequency.weekly => 'Weekly',
    RecurringFrequency.yearly => 'Yearly',
    RecurringFrequency.oneTime => 'One-time',
  };

  static RecurringFrequency fromWire(String v) =>
      RecurringFrequency.values.firstWhere((f) => f.wire == v,
          orElse: () => RecurringFrequency.monthly);
}

/// One recurring income / expense template. The web materialises a real
/// transaction from a due item through the `mark_recurring_generated` RPC
/// (`src/hooks/useRecurring.ts`); this app calls the same RPC.
///
/// Not in the offline cache (M1 audit) — read and written live via PostgREST,
/// like investments and net worth.
class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.type,
    required this.name,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    required this.isActive,
    this.subtype,
    this.notes,
    this.icon,
    this.lastGeneratedAt,
  });

  final String id;
  final RecurringType type;
  final String name;
  final String category;
  final Money amount;
  final RecurringFrequency frequency;

  /// A calendar date (no time). Local midnight.
  final DateTime nextDueDate;
  final bool isActive;
  final String? subtype;
  final String? notes;
  final String? icon;
  final DateTime? lastGeneratedAt;

  bool get isIncome => type == RecurringType.income;

  /// Whole calendar days from today to [nextDueDate] (negative = overdue).
  int daysUntilDue({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final a = DateTime(ref.year, ref.month, ref.day);
    final b = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    return b.difference(a).inDays;
  }

  factory RecurringItem.fromRow(Map<String, dynamic> r) => RecurringItem(
    id: r['id'] as String,
    type: RecurringType.fromWire((r['type'] as String?) ?? 'expense'),
    name: (r['name'] as String?) ?? '',
    category: (r['category'] as String?) ?? 'Other',
    amount: Money(Decimal.parse((r['amount'] ?? 0).toString())),
    frequency: RecurringFrequency.fromWire((r['frequency'] as String?) ?? 'monthly'),
    nextDueDate: _date(r['next_due_date']) ?? DateTime.now(),
    isActive: (r['is_active'] as bool?) ?? true,
    subtype: r['subtype'] as String?,
    notes: r['notes'] as String?,
    icon: r['icon'] as String?,
    lastGeneratedAt: DateTime.tryParse((r['last_generated_at'] as String?) ?? ''),
  );

  /// Parse a Postgres `date` (`YYYY-MM-DD`) as a local calendar date, never
  /// shifted by `.toUtc()` (M10 fix — `RowMappers._date`).
  static DateTime? _date(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

/// A new / edited recurring template.
class RecurringDraft {
  const RecurringDraft({
    required this.type,
    required this.name,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.nextDueDate,
    this.subtype,
    this.notes,
    this.icon,
    this.fxRate = 1,
  });

  final RecurringType type;
  final String name;
  final String category;
  final Money amount;
  final RecurringFrequency frequency;
  final DateTime nextDueDate;
  final String? subtype;
  final String? notes;
  final String? icon;

  /// Rupees per unit of the amount's currency (`fx_rate`); 1 for rupees.
  /// Income streams in dollars or euros pass their rate, as the web does.
  final double fxRate;
}

/// Advance a calendar date by one period.
///
/// Ported from the web `bumpDate` (`src/hooks/useRecurring.ts`) — month / year
/// steps clamp to the last valid day rather than overflowing (Jan 31 + 1 month
/// → Feb 28/29, not Mar 3), matching the server's `mark_recurring_generated`.
/// A parity test pins this to the web arithmetic.
DateTime bumpDate(DateTime date, RecurringFrequency freq) {
  final y = date.year, m = date.month, d = date.day;

  if (freq == RecurringFrequency.weekly) {
    return DateTime(y, m, d + 7);
  }
  if (freq == RecurringFrequency.oneTime) {
    return date; // one-time items deactivate instead of advancing
  }

  var targetY = y;
  var targetM = m;
  if (freq == RecurringFrequency.yearly) {
    targetY = y + 1;
  } else {
    targetM = m == 12 ? 1 : m + 1;
    targetY = m == 12 ? y + 1 : y;
  }

  // Day 0 of the following month == last day of the target month.
  final lastDay = DateTime(targetY, targetM + 1, 0).day;
  return DateTime(targetY, targetM, d < lastDay ? d : lastDay);
}

const List<String> kIncomeSubtypes = ['active', 'passive'];

abstract final class RecurringValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Name this item';
    if (t.length > 60) return 'That name is too long';
    return null;
  }

  static String? amount(String? v) {
    final m = Money.tryParse(v ?? '');
    if (m == null) return 'Enter an amount';
    if (!m.isPositive) return 'Enter an amount above zero';
    if (m > Money.parse('999999999999.99')) return 'That amount is too large';
    return null;
  }

  static String? notes(String? v) {
    if ((v ?? '').length > 500) return 'Keep notes under 500 characters';
    return null;
  }
}

List<String> categoriesFor(RecurringType type) =>
    type == RecurringType.income ? kIncomeCategories : kExpenseCategories;
