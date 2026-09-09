import 'package:intl/intl.dart';

/// Small, dependency-light date phrasing for the UI. Kept here (not in a
/// widget) so it is unit-testable and consistent across screens.
abstract final class RelativeTime {
  /// A short "how long ago" phrase for a point in the past — the sync status
  /// line uses it. [now] is injectable for tests.
  ///
  /// `just now` · `5m ago` · `3h ago` · `yesterday` · `4d ago` · `12 Aug`.
  static String short(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final t = time.toLocal();
    final delta = ref.difference(t);

    if (delta.isNegative) return 'just now';
    if (delta.inSeconds < 45) return 'just now';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';

    final days = _calendarDaysBetween(t, ref);
    if (days == 1) return 'yesterday';
    if (days < 7) return '${days}d ago';
    return DateFormat('d MMM').format(t);
  }

  /// A day label for grouping / a transaction row: `Today` · `Yesterday` ·
  /// `Mon` (this week) · `12 Aug` · `12 Aug 2025` (another year).
  static String dayLabel(DateTime date, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final d = date.toLocal();
    final days = _calendarDaysBetween(d, ref);

    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days > 1 && days < 7) return DateFormat('EEEE').format(d);
    if (d.year == ref.year) return DateFormat('d MMM').format(d);
    return DateFormat('d MMM yyyy').format(d);
  }

  /// Whole calendar days from [earlier] to [later], ignoring the time of day.
  static int _calendarDaysBetween(DateTime earlier, DateTime later) {
    final a = DateTime(earlier.year, earlier.month, earlier.day);
    final b = DateTime(later.year, later.month, later.day);
    return b.difference(a).inDays;
  }
}
