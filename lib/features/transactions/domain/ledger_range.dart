import 'package:intl/intl.dart';

/// How far back the phone's cache holds transactions. Mirrors the M5
/// `DeltaPuller.transactionWindow` default (180 days); anything older lives
/// only on the server.
const transactionCacheWindow = Duration(days: 180);

/// The oldest moment the cache is expected to cover at [now].
DateTime transactionCacheStart(DateTime now) =>
    now.subtract(transactionCacheWindow);

/// True when a window starting at [from] reaches past what the cache holds.
bool startsBeforeCache(DateTime from, DateTime now) =>
    from.isBefore(transactionCacheStart(now));

/// The ledger's quick date choices.
enum LedgerRangePreset {
  thisMonth('This month'),
  lastMonth('Last month'),
  last30Days('Last 30 days'),
  thisYear('This year'),
  custom('Custom');

  const LedgerRangePreset(this.label);
  final String label;
}

/// A date window on the ledger: `[from, toExclusive)` in local time.
class LedgerRange {
  const LedgerRange._(this.preset, this.from, this.toExclusive);

  /// A preset resolved against [now]. [LedgerRangePreset.custom] is not a
  /// preset you can resolve — use [LedgerRange.custom].
  factory LedgerRange.preset(LedgerRangePreset preset, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (preset) {
      LedgerRangePreset.thisMonth => LedgerRange._(
        preset,
        DateTime(now.year, now.month),
        tomorrow,
      ),
      LedgerRangePreset.lastMonth => LedgerRange._(
        preset,
        DateTime(now.year, now.month - 1),
        DateTime(now.year, now.month),
      ),
      LedgerRangePreset.last30Days => LedgerRange._(
        preset,
        DateTime(today.year, today.month, today.day - 29),
        tomorrow,
      ),
      LedgerRangePreset.thisYear => LedgerRange._(
        preset,
        DateTime(now.year),
        tomorrow,
      ),
      LedgerRangePreset.custom => throw ArgumentError(
        'Use LedgerRange.custom for a custom range',
      ),
    };
  }

  /// Whole days from [start] through [endInclusive] (both by calendar day).
  factory LedgerRange.custom(DateTime start, DateTime endInclusive) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(
      endInclusive.year,
      endInclusive.month,
      endInclusive.day + 1,
    );
    return LedgerRange._(LedgerRangePreset.custom, from, to);
  }

  final LedgerRangePreset preset;
  final DateTime from;
  final DateTime toExclusive;

  /// The last day included.
  DateTime get lastDay =>
      DateTime(toExclusive.year, toExclusive.month, toExclusive.day - 1);

  /// "This month", or for a custom range "5 Mar – 12 Apr 2026".
  String get label {
    if (preset != LedgerRangePreset.custom) return preset.label;
    final end = lastDay;
    final sameYear = from.year == end.year;
    final startFmt = sameYear ? DateFormat('d MMM') : DateFormat('d MMM y');
    if (from == end) return DateFormat('d MMM y').format(from);
    return '${startFmt.format(from)} – ${DateFormat('d MMM y').format(end)}';
  }

  @override
  bool operator ==(Object other) =>
      other is LedgerRange &&
      other.preset == preset &&
      other.from == from &&
      other.toExclusive == toExclusive;

  @override
  int get hashCode => Object.hash(preset, from, toExclusive);
}
