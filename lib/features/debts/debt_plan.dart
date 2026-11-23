import 'package:uuid/uuid.dart';

/// The EMI schedule of a debt and the rows the web writes for it — the Dart
/// twin of `buildInstallments` / `computeMonthly` (`src/lib/debtsStore.ts`)
/// and of the reminders the web's TransactionDialog schedules per EMI. Pure,
/// so a debt added on the phone is the same row a web-made one would be
/// (`test/features/debts/debt_plan_test.dart`).

/// `yyyy-MM-dd`.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// [first] moved by [months], overflowing like JavaScript's `setMonth`
/// (31 Jan + 1 month = 3 Mar) — the web's `addMonths`, so both apps put each
/// EMI on the same day.
DateTime emiDate(DateTime first, int months) =>
    DateTime(first.year, first.month + months, first.day);

/// Web `computeMonthly`: total ÷ months, unrounded (0 when either is empty).
double computeMonthly(double total, int months) =>
    (!total.isFinite || total <= 0 || months <= 0) ? 0 : total / months;

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Web `buildInstallments`: equal EMIs rounded to paise, the last one taking
/// the remainder so they add up to [total] exactly.
List<Map<String, dynamic>> buildInstallments(
  double total,
  int months,
  DateTime firstDue,
) {
  if (!total.isFinite || total <= 0 || months <= 0) return const [];
  final monthly = _round2(total / months);
  final list = <Map<String, dynamic>>[];
  var accounted = 0.0;
  for (var i = 0; i < months; i++) {
    final last = i == months - 1;
    final amount = last ? _round2(total - accounted) : monthly;
    accounted += amount;
    list.add({
      'month': i + 1,
      'dueDate': isoDay(emiDate(firstDue, i)),
      'amount': amount,
      'status': 'pending',
    });
  }
  return list;
}

/// What the person typed for a debt.
class DebtDraft {
  const DebtDraft({
    required this.lender,
    required this.category,
    required this.total,
    required this.months,
    required this.firstDue,
    this.notes = '',
    this.currency = 'INR',
  });

  final String lender;
  final String category;
  final double total;
  final int months;
  final DateTime firstDue;
  final String notes;
  final String currency;
}

/// A `reminders` row for one EMI, as the web writes it.
Map<String, dynamic> emiReminderRow({
  required String id,
  required String tenantId,
  required String debtId,
  required DebtDraft d,
  required Map<String, dynamic> installment,
  required DateTime now,
}) {
  final month = installment['month'] as int;
  return {
    'id': id,
    'tenant_id': tenantId,
    'title': '${d.lender.trim()} · EMI $month/${d.months}',
    'context': 'fixed_due',
    'due_date': installment['dueDate'],
    'amount': installment['amount'],
    'currency': d.currency,
    'frequency': 'one_time',
    'grace': '3d',
    'source': 'debt',
    'source_id': debtId,
    'status': 'scheduled',
    'notes':
        'Upcoming Debt Paydown: Month $month of ${d.months} for '
        '${d.lender.trim()} is due soon.',
    'debt': {
      'debtId': debtId,
      'month': month,
      'totalMonths': d.months,
      'lender': d.lender.trim(),
    },
    'created_at': now.toUtc().toIso8601String(),
  };
}

/// Everything a new debt writes: the `debts` row and, when reminders are
/// available, one reminder per EMI (each installment then carries its
/// `reminderId`, as on the web).
({Map<String, dynamic> debt, List<Map<String, dynamic>> reminders})
planNewDebt({
  required String tenantId,
  required DebtDraft d,
  required bool withReminders,
  required DateTime now,
  String? debtId,
  Uuid uuid = const Uuid(),
}) {
  final id = debtId ?? uuid.v4();
  final reminders = <Map<String, dynamic>>[];
  final installments = [
    for (final inst in buildInstallments(d.total, d.months, d.firstDue))
      if (withReminders)
        () {
          final rid = uuid.v4();
          reminders.add(
            emiReminderRow(
              id: rid,
              tenantId: tenantId,
              debtId: id,
              d: d,
              installment: inst,
              now: now,
            ),
          );
          return {...inst, 'reminderId': rid};
        }()
      else
        inst,
  ];
  return (
    debt: {
      'id': id,
      'tenant_id': tenantId,
      ...debtFields(d),
      'installments': installments,
      'created_at': now.toUtc().toIso8601String(),
    },
    reminders: reminders,
  );
}

/// The columns an edit may change without touching the schedule.
Map<String, dynamic> debtFields(DebtDraft d) => {
  'lender': d.lender.trim(),
  'category': d.category,
  'currency': d.currency,
  'total_amount': d.total,
  'duration': d.months,
  'monthly': computeMonthly(d.total, d.months),
  'first_due_date': isoDay(d.firstDue),
  'notes': d.notes.trim().isEmpty ? null : d.notes.trim(),
};

abstract final class DebtValidators {
  static String? lender(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Add the lender or source';
    if (t.length > 80) return 'That name is too long';
    return null;
  }

  static String? total(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter the amount borrowed';
    if (n > 999999999999) return 'That amount is too large';
    return null;
  }

  static String? months(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 1) return 'How many monthly EMIs?';
    if (n > 360) return 'Up to 360 months';
    return null;
  }
}
