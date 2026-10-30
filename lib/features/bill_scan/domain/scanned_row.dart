import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money/money.dart';
import 'scan_result.dart';

const _uuid = Uuid();

/// `item` — a real purchased line, a full editable card. `tax` — a
/// CGST/SGST/service-charge/round-off line, shown in a compact strip. Both fold
/// into the single approved transaction (web `ScannedRow.kind`).
enum ScanRowKind { item, tax }

/// One reviewable line in the scan result. The *review* is granular; the ledger
/// entry that results is always one transaction (web `src/lib/billScan.ts`).
class ScannedRow {
  ScannedRow({
    required this.name,
    required this.category,
    required this.amount,
    required this.date,
    required this.kind,
    this.qty = 1,
    this.unit = 'pc',
    String? id,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String name;
  final String category;
  final Money amount;
  final DateTime date;
  final double qty;
  final String unit;
  final ScanRowKind kind;

  ScannedRow copyWith({
    String? name,
    String? category,
    Money? amount,
    DateTime? date,
  }) =>
      ScannedRow(
        id: id,
        name: name ?? this.name,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        qty: qty,
        unit: unit,
        kind: kind,
      );
}

enum ScanMode { lumpsum, lineItem }

/// Line-item mode: one row per item + one per tax line (kept separate, never
/// merged). Lumpsum mode: one row for the whole receipt using its *stated*
/// total (not a re-sum), so it matches what was charged even if the AI missed a
/// line. Ported from web `rowsFromScanResult`.
List<ScannedRow> rowsFromScanResult(
  ScanResult result,
  ScanMode mode,
  DateTime today,
) {
  // A receipt usually prints only a date (parsed as midnight); every logged
  // transaction needs a time too, so borrow the time of day from [today].
  final printed = result.date;
  final date = printed == null
      ? today
      : (printed.hour == 0 && printed.minute == 0
            ? DateTime(
                printed.year,
                printed.month,
                printed.day,
                today.hour,
                today.minute,
              )
            : printed);
  final fallbackCategory =
      result.items.isNotEmpty ? result.items.first.category : 'Shopping';

  if (mode == ScanMode.lumpsum) {
    return [
      ScannedRow(
        name: result.merchant.isNotEmpty ? result.merchant : 'Receipt',
        category: fallbackCategory,
        amount: result.total,
        date: date,
        kind: ScanRowKind.item,
      ),
    ];
  }

  return [
    for (final it in result.items)
      ScannedRow(
        name: it.name,
        category: it.category,
        amount: it.amount,
        date: date,
        qty: it.qty,
        unit: it.unit,
        kind: ScanRowKind.item,
      ),
    for (final t in result.taxLines)
      if (t.amount.amount.abs() > (Decimal.parse('0.005')))
        ScannedRow(
          name: t.label,
          category: fallbackCategory,
          amount: t.amount,
          date: date,
          kind: ScanRowKind.tax,
        ),
  ];
}

/// What Approve logs — always ONE expense, no matter how many rows were
/// reviewed. Sums the CURRENT row amounts (so a correction during review
/// counts); category is the most common across the rows, ties keep the first.
/// Ported from web `buildApprovalTransaction`.
ApprovalTransaction? buildApprovalTransaction(
  List<ScannedRow> rows,
  String merchant,
) {
  if (rows.isEmpty) return null;
  final currency = rows.first.amount.currency;
  var amount = Money.zero(currency);
  for (final r in rows) {
    amount = amount + Money(r.amount.amount, currency);
  }

  final counts = <String, int>{};
  for (final r in rows) {
    counts[r.category] = (counts[r.category] ?? 0) + 1;
  }
  var category = rows.first.category;
  var best = 0;
  for (final e in counts.entries) {
    if (e.value > best) {
      best = e.value;
      category = e.key;
    }
  }

  return ApprovalTransaction(
    amount: amount,
    category: category,
    description: merchant.trim().isNotEmpty ? merchant.trim() : rows.first.name,
    date: rows.first.date,
  );
}

class ApprovalTransaction {
  const ApprovalTransaction({
    required this.amount,
    required this.category,
    required this.description,
    required this.date,
  });

  final Money amount;
  final String category;
  final String description;
  final DateTime date;
}

/// Cross-check the reviewed rows against the receipt's printed total. A few
/// paise of rounding drift is fine; more than ₹0.50 is worth a second look.
/// Ported from web `reconcileTotal`.
class Reconciliation {
  const Reconciliation({
    required this.computed,
    required this.stated,
    required this.matches,
    required this.diff,
  });

  final Money computed;
  final Money stated;
  final bool matches;
  final Money diff;

  static Reconciliation of(List<ScannedRow> rows, Money statedTotal) {
    final currency = statedTotal.currency;
    var computed = Money.zero(currency);
    for (final r in rows) {
      computed = computed + Money(r.amount.amount, currency);
    }
    final diff = computed - statedTotal;
    return Reconciliation(
      computed: computed,
      stated: statedTotal,
      matches: diff.amount.abs() <= Decimal.parse('0.5'),
      diff: diff,
    );
  }
}

({List<ScannedRow> items, List<ScannedRow> taxes}) partitionRows(
  List<ScannedRow> rows,
) => (
  items: [for (final r in rows) if (r.kind == ScanRowKind.item) r],
  taxes: [for (final r in rows) if (r.kind == ScanRowKind.tax) r],
);
