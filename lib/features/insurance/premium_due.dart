/// When an insurance premium falls due — pure date arithmetic shared by the
/// notification planner and its tests. Mirrors the web's
/// `src/lib/premiumDue.ts`.
library;

/// Months between premiums for a `payment_frequency` (web
/// `PAYMENT_FREQUENCIES`). `One-Time` → 0 (it never repeats). A missing or
/// unknown value counts as Annual, as `yearlyPremium` does.
int premiumIntervalMonths(String? frequency) => switch (frequency) {
  'Monthly' => 1,
  'Quarterly' => 3,
  'Half-Yearly' => 6,
  'One-Time' => 0,
  _ => 12,
};

/// The premium [k] cycles after [anchor], counted from [anchor] itself so a
/// policy due on the 31st returns to the 31st after a short month
/// (31 Jan → 28/29 Feb → 31 Mar).
DateTime premiumDueAfter(DateTime anchor, String? frequency, int k) {
  final months = premiumIntervalMonths(frequency) * k;
  final first = DateTime(anchor.year, anchor.month + months);
  final last = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(
    first.year,
    first.month,
    anchor.day > last ? last : anchor.day,
  );
}

/// The first premium due on or after [onOrAfter] (date only), stepping
/// forward from the stored [dueDate] by whole cycles. A one-time premium is
/// returned only while it is still to come; otherwise null.
DateTime? nextPremiumDue(
  DateTime? dueDate,
  String? frequency,
  DateTime onOrAfter,
) {
  if (dueDate == null) return null;
  final day = DateTime(onOrAfter.year, onOrAfter.month, onOrAfter.day);
  final anchor = DateTime(dueDate.year, dueDate.month, dueDate.day);
  if (premiumIntervalMonths(frequency) == 0) {
    return anchor.isBefore(day) ? null : anchor;
  }
  for (var k = 0; k < 2000; k++) {
    final d = premiumDueAfter(anchor, frequency, k);
    if (!d.isBefore(day)) return d;
  }
  return null;
}
