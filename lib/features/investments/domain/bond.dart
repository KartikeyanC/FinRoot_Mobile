import 'dart:math' as math;

/// Bond holdings: the inputs, kept in the holding's `fields` map under the
/// SAME keys the web's bond calculator uses (`src/lib/bonds.ts`), and the
/// figures both apps derive from them. Pure Dart, no Flutter, so the maths is
/// unit-tested on its own (`test/features/investments/bond_test.dart`) and
/// matches the web's port line for line.
///
/// Keys in `fields`:
///   face_value, bond_units, coupon_rate, purchase_date, maturity_date
///   (ISO `yyyy-MM-dd`), issuer, rating. The payout frequency is the
///   table's own `bond_freq` column and is mirrored in `fields.bond_freq`.
abstract final class BondKeys {
  static const faceValue = 'face_value';
  static const units = 'bond_units';
  static const couponRate = 'coupon_rate';
  static const frequency = 'bond_freq';
  static const purchaseDate = 'purchase_date';
  static const maturityDate = 'maturity_date';
  static const issuer = 'issuer';
  static const rating = 'rating';

  /// The web's older bond form saved the rate as `xirr`; read it as a
  /// fallback so those holdings still get figures.
  static const legacyRate = 'xirr';

  static const all = [
    faceValue,
    units,
    couponRate,
    frequency,
    purchaseDate,
    maturityDate,
    issuer,
    rating,
  ];
}

/// How often the bond pays interest. [label] is what is stored and shown.
enum BondFrequency {
  monthly('Monthly', 12),
  quarterly('Quarterly', 4),
  halfYearly('Half-yearly', 2),
  yearly('Yearly', 1),
  atMaturity('At maturity', 0);

  const BondFrequency(this.label, this.perYear);

  final String label;

  /// Payouts per year; 0 = cumulative, everything is paid at maturity.
  final int perYear;

  int get monthsBetween => perYear == 0 ? 0 : 12 ~/ perYear;

  static BondFrequency parse(Object? v) {
    final s = '${v ?? ''}'.trim().toLowerCase().replaceAll(' ', '');
    for (final f in values) {
      if (f.label.toLowerCase().replaceAll(' ', '') == s) return f;
    }
    if (s == 'halfyearly' || s == 'semiannual' || s == 'semi-annual') {
      return halfYearly;
    }
    return yearly;
  }
}

/// Credit ratings offered in the picker.
const List<String> kBondRatings = ['AAA', 'AA', 'A', 'BBB', 'Unrated'];

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final n = double.tryParse('$v'.trim());
  return (n == null || !n.isFinite) ? null : n;
}

DateTime? _date(Object? v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] moved by [months], clamping the day to the target month's length
/// (31 Jan − 1 month = 31 Dec; 31 Mar − 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last));
}

/// What the user entered for one bond holding.
class BondTerms {
  const BondTerms({
    this.faceValue,
    this.units,
    this.couponRate,
    this.frequency = BondFrequency.yearly,
    this.purchaseDate,
    this.maturityDate,
    this.issuer = '',
    this.rating,
  });

  final double? faceValue;
  final double? units;

  /// Annual coupon, in percent (7.5 = 7.5% a year).
  final double? couponRate;
  final BondFrequency frequency;
  final DateTime? purchaseDate;
  final DateTime? maturityDate;
  final String issuer;
  final String? rating;

  factory BondTerms.fromFields(Map<String, dynamic> f) => BondTerms(
    faceValue: _num(f[BondKeys.faceValue]),
    units: _num(f[BondKeys.units]),
    couponRate: _num(f[BondKeys.couponRate]) ?? _num(f[BondKeys.legacyRate]),
    frequency: BondFrequency.parse(f[BondKeys.frequency]),
    purchaseDate: _date(f[BondKeys.purchaseDate]),
    maturityDate: _date(f[BondKeys.maturityDate]),
    issuer: '${f[BondKeys.issuer] ?? ''}'.trim(),
    rating: kBondRatings.contains(f[BondKeys.rating])
        ? f[BondKeys.rating] as String
        : null,
  );

  /// The keys to merge into `fields`. Blank optional values are written as
  /// empty strings so a cleared box really clears on both apps.
  Map<String, String> toFields() => {
    BondKeys.faceValue: _fmt(faceValue),
    BondKeys.units: _fmt(units),
    BondKeys.couponRate: _fmt(couponRate),
    BondKeys.frequency: frequency.label,
    BondKeys.purchaseDate: purchaseDate == null ? '' : isoDate(purchaseDate!),
    BondKeys.maturityDate: maturityDate == null ? '' : isoDate(maturityDate!),
    BondKeys.issuer: issuer.trim(),
    BondKeys.rating: rating ?? '',
  };

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  /// Total face value, or null when face value / units are not both given.
  double? get faceTotal {
    final f = faceValue, u = units;
    if (f == null || u == null || f <= 0 || u <= 0) return null;
    return f * u;
  }

  /// Every payout date strictly after the purchase date, up to and including
  /// maturity. Coupon dates run back from maturity in whole periods, the way
  /// bond schedules are set. Cumulative bonds pay once, at maturity.
  List<DateTime> payoutDates() {
    final start = purchaseDate, end = maturityDate;
    if (start == null || end == null || !end.isAfter(start)) return const [];
    if (frequency.perYear == 0) return [end];
    final out = <DateTime>[];
    for (var k = 0; ; k++) {
      final d = addMonths(end, -k * frequency.monthsBetween);
      if (!d.isAfter(start)) break;
      out.add(d);
      if (k > 1200) break; // 100 years of monthly coupons; never reached
    }
    return out.reversed.toList();
  }
}

/// Figures derived from [BondTerms] and the amount invested.
class BondFigures {
  const BondFigures({
    required this.accruedInterest,
    required this.estimatedValue,
    required this.yieldToMaturity,
    required this.nextPayout,
    required this.maturityAmount,
    required this.daysToMaturity,
  });

  /// Interest earned but not yet paid out, as of today.
  final double accruedInterest;

  /// Amount invested + [accruedInterest]: the default current value.
  final double estimatedValue;

  /// Annual yield, in percent, if held from purchase to maturity at the price
  /// paid (the amount invested). Null when the terms are incomplete.
  final double? yieldToMaturity;

  /// The next date interest is paid; null once the bond has matured.
  final DateTime? nextPayout;

  /// What is paid out on the maturity date (principal plus the last coupon,
  /// or principal plus all interest for a cumulative bond).
  final double? maturityAmount;

  /// Days from today to maturity; 0 once matured, null without a date.
  final int? daysToMaturity;

  static BondFigures of(
    BondTerms t, {
    required double invested,
    required DateTime asOf,
  }) {
    final today = _day(asOf);
    final principal = t.faceTotal ?? (invested > 0 ? invested : 0.0);
    final rate = (t.couponRate ?? 0) / 100;
    final start = t.purchaseDate;
    final end = t.maturityDate;
    final payouts = t.payoutDates();

    // ---- Accrued interest (simple, actual/365) ----
    var accrued = 0.0;
    if (start != null && rate > 0 && principal > 0 && today.isAfter(start)) {
      final until = (end != null && today.isAfter(end)) ? end : today;
      DateTime from;
      if (t.frequency.perYear == 0) {
        from = start;
      } else {
        // Since the last payout on or before today (or the purchase date).
        from = start;
        for (final p in payouts) {
          if (!p.isAfter(until)) from = p;
        }
      }
      if (t.frequency.perYear == 0) {
        final years = until.difference(from).inDays / 365;
        accrued = principal * (math.pow(1 + rate, years) - 1);
      } else {
        accrued = principal * rate * until.difference(from).inDays / 365;
      }
      if (end != null && !today.isBefore(end)) accrued = 0; // paid out
    }

    // ---- Next payout ----
    DateTime? next;
    for (final p in payouts) {
      if (p.isAfter(today)) {
        next = p;
        break;
      }
    }

    // ---- Maturity amount ----
    double? maturity;
    if (end != null && start != null && end.isAfter(start) && principal > 0) {
      if (t.frequency.perYear == 0) {
        final years = end.difference(start).inDays / 365;
        maturity = principal * math.pow(1 + rate, years);
      } else {
        maturity = principal + principal * rate / t.frequency.perYear;
      }
    }

    final days = end == null ? null : math.max(0, end.difference(today).inDays);

    return BondFigures(
      accruedInterest: _round2(accrued),
      estimatedValue: _round2((invested > 0 ? invested : 0) + accrued),
      yieldToMaturity: _ytm(t, invested: invested, principal: principal),
      nextPayout: next,
      maturityAmount: maturity == null ? null : _round2(maturity),
      daysToMaturity: days,
    );
  }

  /// Rate y (annual, effective) at which the cash flows from purchase to
  /// maturity are worth exactly the amount invested. Bisection, so it never
  /// diverges; null when there is nothing to solve.
  static double? _ytm(
    BondTerms t, {
    required double invested,
    required double principal,
  }) {
    final start = t.purchaseDate, end = t.maturityDate;
    if (start == null || end == null || !end.isAfter(start)) return null;
    if (invested <= 0 || principal <= 0 || t.couponRate == null) return null;
    final rate = t.couponRate! / 100;

    final flows = <(double, double)>[]; // (years from purchase, amount)
    double years(DateTime d) => d.difference(start).inDays / 365;
    if (t.frequency.perYear == 0) {
      flows.add((
        years(end),
        principal * math.pow(1 + rate, years(end)).toDouble(),
      ));
    } else {
      final coupon = principal * rate / t.frequency.perYear;
      final dates = t.payoutDates();
      for (final d in dates) {
        flows.add((years(d), coupon + (d == end ? principal : 0)));
      }
    }
    if (flows.isEmpty) return null;

    double pv(double y) {
      var s = 0.0;
      for (final (yr, amt) in flows) {
        s += amt / math.pow(1 + y, yr);
      }
      return s;
    }

    var lo = -0.99, hi = 5.0;
    if (pv(lo) < invested || pv(hi) > invested) return null;
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      if (pv(mid) > invested) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _round2((lo + hi) / 2 * 100);
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

abstract final class BondValidators {
  static String? couponRate(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Enter the coupon rate';
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n < 0 || n > 30) {
      return 'Use a rate between 0 and 30%';
    }
    return null;
  }

  /// Face value and units are optional, but above zero when given.
  static String? positiveOptional(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n <= 0) return 'Enter a number above 0';
    return null;
  }

  static String? purchaseDate(DateTime? d, {required DateTime today}) {
    if (d == null) return 'Pick the purchase date';
    if (_day(d).isAfter(_day(today))) return 'Purchase date can\'t be ahead';
    return null;
  }

  static String? maturityDate(
    DateTime? d, {
    required DateTime? purchase,
    required DateTime today,
  }) {
    if (d == null) return 'Pick the maturity date';
    if (purchase != null && !_day(d).isAfter(_day(purchase))) {
      return 'Must be after the purchase date';
    }
    if (!_day(d).isAfter(_day(today))) return 'Must be in the future';
    return null;
  }
}
