import 'package:intl/intl.dart';

import 'currency.dart';

/// Money formatting — mirrors `formatMoney` / `formatCompact` in the web repo's
/// `src/lib/finance.ts` (see the note in `currency.dart`).
///
/// Rules copied exactly:
/// - the sign goes OUTSIDE the symbol: `-₹100`, never `₹-100`;
/// - a non-finite figure renders as `—` (em dash), never `₹NaN` — "a wrong
///   number that looks like a number is worse than an honest blank";
/// - Indian digit grouping (`en_IN`: lakh, crore).
abstract final class MoneyFormat {
  static final NumberFormat _grouped = NumberFormat.decimalPattern('en_IN')
    ..maximumFractionDigits = 2;
  static final NumberFormat _groupedWhole = NumberFormat.decimalPattern('en_IN')
    ..maximumFractionDigits = 0;

  static const String blank = '—';

  /// e.g. `₹18,600`, `-₹1,240.50`, `$1,20,000`.
  static String money(num amount, {String currency = 'INR'}) {
    final n = amount.toDouble();
    if (!n.isFinite) return blank;
    final sym = currencySymbol(currency);
    final sign = n < 0 ? '-' : '';
    return '$sign$sym${_grouped.format(n.abs())}';
  }

  /// Whole-rupee variant for dense contexts (chips, axis labels).
  static String compact(num amount, {String currency = 'INR'}) {
    final n = amount.toDouble();
    if (!n.isFinite) return blank;
    final sym = currencySymbol(currency);
    final sign = n < 0 ? '-' : '';
    return '$sign$sym${_groupedWhole.format(n.abs().round())}';
  }

  /// Lakh/crore short form for hero figures, e.g. `₹2.84L`, `₹1.20Cr`.
  static String short(num amount, {String currency = 'INR'}) {
    final n = amount.toDouble();
    if (!n.isFinite) return blank;
    final sym = currencySymbol(currency);
    final sign = n < 0 ? '-' : '';
    final abs = n.abs();
    if (abs >= 10000000) {
      return '$sign$sym${(abs / 10000000).toStringAsFixed(2)}Cr';
    }
    if (abs >= 100000) {
      return '$sign$sym${(abs / 100000).toStringAsFixed(2)}L';
    }
    if (abs >= 1000) {
      return '$sign$sym${(abs / 1000).toStringAsFixed(1)}k';
    }
    return '$sign$sym${_groupedWhole.format(abs.round())}';
  }
}
