import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';

/// `reminders.context` CHECK. What kind of thing is being tracked.
enum ReminderContext {
  fixedDue('fixed_due'),
  balanceBuffer('balance_buffer'),
  maturity('maturity');

  const ReminderContext(this.wire);
  final String wire;

  String get label => switch (this) {
    ReminderContext.fixedDue => 'Fixed due date',
    ReminderContext.balanceBuffer => 'Balance buffer alert',
    ReminderContext.maturity => 'Maturity horizon',
  };

  String get hint => switch (this) {
    ReminderContext.fixedDue => 'Credit cards, utilities, rent & EMI',
    ReminderContext.balanceBuffer => 'SIPs, mutual funds & RDs',
    ReminderContext.maturity => 'Fixed deposits & bonds',
  };

  IconData get icon => switch (this) {
    ReminderContext.fixedDue => Icons.event_outlined,
    ReminderContext.balanceBuffer => Icons.account_balance_wallet_outlined,
    ReminderContext.maturity => Icons.hourglass_bottom_outlined,
  };

  static ReminderContext fromWire(String v) =>
      ReminderContext.values.firstWhere((c) => c.wire == v,
          orElse: () => ReminderContext.fixedDue);
}

/// `reminders.frequency` for a fixed-due reminder (nullable in the DB).
enum ReminderFrequency {
  oneTime('one_time'),
  monthly('monthly'),
  quarterly('quarterly');

  const ReminderFrequency(this.wire);
  final String wire;

  String get label => switch (this) {
    ReminderFrequency.oneTime => 'One-time',
    ReminderFrequency.monthly => 'Monthly',
    ReminderFrequency.quarterly => 'Quarterly',
  };

  static ReminderFrequency? fromWire(String? v) => switch (v) {
    'one_time' => ReminderFrequency.oneTime,
    'monthly' => ReminderFrequency.monthly,
    'quarterly' => ReminderFrequency.quarterly,
    _ => null,
  };
}

/// A standalone reminder (`public.reminders`). The web model
/// (`src/lib/remindersStore.ts`) also carries debt-installment linkage, grace
/// windows, maturity leads and liquidity checks; this app **round-trips** those
/// fields untouched (`_extra`) but does not edit them in V1 — see the M12
/// report. Menu-gated (`reminders`), online-only, not cached.
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    required this.context,
    required this.dueDate,
    required this.status,
    this.amount,
    this.notes,
    this.frequency,
    this.createdAt,
    this.extra = const {},
  });

  final String id;
  final String title;
  final ReminderContext context;

  /// Calendar date (no time), local midnight.
  final DateTime dueDate;

  /// `scheduled` | `completed`.
  final String status;
  final Money? amount;
  final String? notes;
  final ReminderFrequency? frequency;
  final DateTime? createdAt;

  /// Fields the web owns that mobile persists verbatim: `grace`,
  /// `verify_liquidity`, `maturity_leads`, `debt`, `source`, `source_id`,
  /// `currency`.
  final Map<String, dynamic> extra;

  bool get isCompleted => status == 'completed';

  int daysUntilDue({DateTime? now}) {
    final ref = now ?? DateTime.now();
    final a = DateTime(ref.year, ref.month, ref.day);
    final b = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return b.difference(a).inDays;
  }

  /// Roll a past-due reminder forward for DISPLAY only (no write-on-read) —
  /// ported from the web `rollForward`. A recurring fixed-due reminder jumps to
  /// its next occurrence; anything else past due reads as completed.
  Reminder rolledForward({DateTime? now}) {
    if (isCompleted) return this;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (!due.isBefore(today)) return this;

    if (context == ReminderContext.fixedDue &&
        frequency != null &&
        frequency != ReminderFrequency.oneTime) {
      final step = frequency == ReminderFrequency.monthly ? 1 : 3;
      var next = due;
      while (next.isBefore(today)) {
        next = DateTime(next.year, next.month + step, next.day);
      }
      return _copyWith(dueDate: next);
    }
    return _copyWith(status: 'completed');
  }

  Reminder _copyWith({DateTime? dueDate, String? status}) => Reminder(
    id: id,
    title: title,
    context: context,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    amount: amount,
    notes: notes,
    frequency: frequency,
    createdAt: createdAt,
    extra: extra,
  );

  factory Reminder.fromRow(Map<String, dynamic> r) {
    final currency = (r['currency'] as String?) ?? 'INR';
    final rawAmount = r['amount'];
    return Reminder(
      id: r['id'] as String,
      title: (r['title'] as String?) ?? '',
      context: ReminderContext.fromWire((r['context'] as String?) ?? 'fixed_due'),
      dueDate: _date(r['due_date']) ?? DateTime.now(),
      status: (r['status'] as String?) ?? 'scheduled',
      amount: rawAmount == null
          ? null
          : Money(Decimal.parse(rawAmount.toString()), currency),
      notes: r['notes'] as String?,
      frequency: ReminderFrequency.fromWire(r['frequency'] as String?),
      createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
      extra: {
        'currency': currency,
        'source': r['source'],
        'source_id': r['source_id'],
        'grace': r['grace'],
        'verify_liquidity': r['verify_liquidity'],
        'maturity_leads': r['maturity_leads'],
        'debt': r['debt'],
      },
    );
  }

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    final s = v.toString();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.context,
    required this.dueDate,
    this.amount,
    this.notes,
    this.frequency,
  });

  final String title;
  final ReminderContext context;
  final DateTime dueDate;
  final Money? amount;
  final String? notes;
  final ReminderFrequency? frequency;
}

/// The message the web shows for a reminder ("Your X payment is due in 3
/// days.") — a custom note wins.
String reminderMessage(Reminder r, {DateTime? now}) {
  final note = r.notes?.trim();
  if (note != null && note.isNotEmpty) return note;
  final name = r.title.trim().isEmpty ? 'scheduled item' : r.title.trim();
  final d = r.daysUntilDue(now: now);
  final phrase = switch (d) {
    < 0 => 'was due ${d == -1 ? 'yesterday' : '${-d} days ago'}',
    0 => 'is due today',
    1 => 'is due tomorrow',
    _ => 'is due in $d days',
  };
  return switch (r.context) {
    ReminderContext.fixedDue => 'Reminder: your $name payment $phrase.',
    ReminderContext.balanceBuffer =>
      'Heads up: $name will debit shortly — check your funding balance.',
    ReminderContext.maturity =>
      '$name is approaching maturity — plan your reallocation.',
  };
}

abstract final class ReminderValidators {
  static String? title(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Give this reminder a short name';
    if (t.length > 80) return 'That name is too long';
    return null;
  }

  static String? amount(String? v) {
    if ((v ?? '').trim().isEmpty) return null; // optional
    final m = Money.tryParse(v!);
    if (m == null) return 'Enter a valid amount';
    if (m.isNegative) return 'Amount cannot be negative';
    if (m > Money.parse('999999999999.99')) return 'That amount is too large';
    return null;
  }
}
