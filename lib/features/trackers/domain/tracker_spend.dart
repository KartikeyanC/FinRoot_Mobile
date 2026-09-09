import 'package:decimal/decimal.dart';

import '../../../core/money/currency.dart' show toInr;
import '../../../core/money/money.dart';
import 'tracker.dart';

/// Tracker arithmetic — ported from the FinRoot **web** repo's
/// `src/lib/trackers.ts` `foldTrackerSpend` (the pure core; ADR-0006 — there is
/// no `spent` column and there must never be one). `tracker_spend_parity_test`
/// pins it against `trackers.test.ts`.
///
/// Expenses and income are kept **separate**: netting a refund against a build
/// would make the build look cheaper than it was, and "what has this cost me"
/// is the question the feature exists to answer. Transfers count in neither.

/// One row of `tracker_spend()` — per tracker, per type, per currency.
class TrackerSpendRow {
  const TrackerSpendRow({
    required this.trackerId,
    required this.type,
    required this.currency,
    required this.total,
    required this.count,
  });

  final String trackerId;
  final String type; // income | expense | transfer
  final String currency;
  final Decimal total;
  final int count;

  factory TrackerSpendRow.fromJson(Map<String, dynamic> j) => TrackerSpendRow(
    trackerId: j['tracker_id'] as String,
    type: (j['type'] as String?) ?? 'expense',
    currency: (j['currency'] as String?) ?? 'INR',
    total: Decimal.parse(((j['total'] ?? 0)).toString()),
    count: ((j['count'] as num?) ?? 0).toInt(),
  );
}

/// A tracker with its derived figures folded on.
class TrackerWithSpend {
  const TrackerWithSpend({
    required this.tracker,
    required this.spent,
    required this.inflow,
    required this.txnCount,
    required this.utilization,
    required this.remaining,
  });

  final TrackerEntity tracker;

  /// Expenses tagged to this tracker, converted to INR. Never netted.
  final Money spent;

  /// Income tagged to this tracker, INR, kept separate.
  final Money inflow;
  final int txnCount;

  /// Percent of budget used; 0 when there is no budget.
  final int utilization;

  /// `budget - spent`; null when there is no budget (absent is not
  /// spent-in-full). May go negative rather than lie about an overrun.
  final Money? remaining;

  bool get hasBudget =>
      tracker.budget != null && tracker.budget!.amount > Decimal.zero;

  bool get isOverBudget => remaining != null && remaining!.amount < Decimal.zero;
}

List<TrackerWithSpend> foldTrackerSpend(
  List<TrackerEntity> trackers,
  List<TrackerSpendRow>? rows,
) {
  final spent = <String, Decimal>{};
  final inflow = <String, Decimal>{};
  final count = <String, int>{};

  for (final r in rows ?? const <TrackerSpendRow>[]) {
    // A row whose tracker we don't know is dropped, never folded elsewhere.
    final inr = Decimal.parse(
      toInr(r.total.toDouble(), r.currency).toString(),
    );
    if (r.type == 'expense') {
      spent[r.trackerId] = (spent[r.trackerId] ?? Decimal.zero) + inr;
    } else if (r.type == 'income') {
      inflow[r.trackerId] = (inflow[r.trackerId] ?? Decimal.zero) + inr;
    }
    // transfers: counted in neither, by design.
    count[r.trackerId] = (count[r.trackerId] ?? 0) + r.count;
  }

  return [
    for (final t in trackers)
      () {
        final s = spent[t.id] ?? Decimal.zero;
        final budget = t.budget?.amount;
        final hasBudget = budget != null && budget > Decimal.zero;
        return TrackerWithSpend(
          tracker: t,
          spent: Money(s),
          inflow: Money(inflow[t.id] ?? Decimal.zero),
          txnCount: count[t.id] ?? 0,
          utilization: hasBudget
              ? (s.toDouble() / budget.toDouble() * 100).round()
              : 0,
          remaining: hasBudget ? Money(budget - s) : null,
        );
      }(),
  ];
}

/// Whether an [occurredAt] falls inside the tracker's half-open date window
/// [start, end). ⚠️ The window is METADATA — it does not decide membership
/// (that is `tracker_id`, set because a person said so). Used only to seed the
/// "assign older transactions" candidate list.
bool isWithinTrackerWindow(DateTime occurredAt, TrackerEntity t) {
  final at = occurredAt.toUtc();
  final start = DateTime.utc(
    t.startDate.year,
    t.startDate.month,
    t.startDate.day,
  );
  if (at.isBefore(start)) return false;
  final end = t.endDate;
  if (end == null) return true;
  final endExclusive = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).add(const Duration(days: 1));
  return at.isBefore(endExclusive);
}
