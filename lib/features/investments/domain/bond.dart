import 'dart:math' as math;

/// Bond holdings: the inputs, kept in the holding's `fields` map under the
/// SAME keys the web's bond calculator uses (`src/lib/bonds.ts`), and the
/// figures both apps derive from them. Pure Dart, no Flutter, so the maths is
/// unit-tested on its own (`test/features/investments/bond_test.dart`) and
/// matches the web's port line for line.
///
/// The inputs follow an Indian bond deal sheet: price per ₹100 of face value,
/// the last interest payment ("IP") date, accrued interest that can be
/// negative when the trade settles before an IP date whose record date has
/// passed, stamp duty, cost to client, TDS, yield to maturity and to call.
/// Day count is actual/365, as on those sheets.
abstract final class BondKeys {
  static const faceValue = 'face_value';
  static const units = 'bond_units';
  static const couponRate = 'coupon_rate';
  static const frequency = 'bond_freq';
  static const purchaseDate = 'purchase_date';
  static const maturityDate = 'maturity_date';
  static const issuer = 'issuer';
  static const rating = 'rating';
  static const ratingAgency = 'rating_agency';
  static const price = 'price';
  static const lastInterestDate = 'last_ip_date';
  static const stampDuty = 'stamp_duty';
  static const maturityValue = 'maturity_value';
  static const tdsRate = 'tds_rate';
  static const bondType = 'bond_type';
  static const callDate = 'call_date';

  /// The web's older bond form saved the rate as `xirr`; read it as a
  /// fallback so those holdings still get figures.
  static const legacyRate = 'xirr';
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

/// Credit rating grades, highest first.
const List<String> kBondRatings = [
  'AAA',
  'AA+',
  'AA',
  'AA-',
  'A+',
  'A',
  'A-',
  'BBB+',
  'BBB',
  'BBB-',
  'BB and below',
  'Unrated',
];

/// Indian credit rating agencies.
const List<String> kBondRatingAgencies = [
  'CRISIL',
  'ICRA',
  'CARE',
  'India Ratings',
  'Acuité',
  'Brickwork',
  'Infomerics',
];

const List<String> kBondTypes = ['Secured', 'Unsecured'];

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final t = '$v'.trim();
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return (n == null || !n.isFinite) ? null : n;
}

DateTime? _date(Object? v) {
  final s = '${v ?? ''}'.trim();
  if (s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

String? _pick(Object? v, List<String> options) {
  final s = '${v ?? ''}'.trim();
  return options.contains(s) ? s : null;
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

int _days(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// [d] moved by [months], clamping the day to the target month's length
/// (31 Jan − 1 month = 31 Dec; 31 Mar − 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12;
  final m = total % 12 + 1;
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, math.min(d.day, last));
}

/// One interest payment the holder is entitled to.
class BondPayout {
  const BondPayout(this.date, this.amount);
  final DateTime date;

  /// Gross, before TDS.
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is BondPayout && other.date == date && other.amount == amount;

  @override
  int get hashCode => Object.hash(date, amount);

  @override
  String toString() => 'BondPayout(${isoDate(date)}, $amount)';
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
    this.ratingAgency,
    this.price,
    this.lastInterestDate,
    this.stampDuty,
    this.maturityValue,
    this.tdsRate,
    this.bondType,
    this.callDate,
  });

  final double? faceValue;
  final double? units;

  /// Annual coupon, in percent (7.5 = 7.5% a year).
  final double? couponRate;
  final BondFrequency frequency;

  /// The transaction (settlement) date.
  final DateTime? purchaseDate;
  final DateTime? maturityDate;
  final String issuer;
  final String? rating;
  final String? ratingAgency;

  /// Clean price per ₹100 of face value (102 = 2% premium).
  final double? price;

  /// The interest payment date the accrued interest runs from. It may fall
  /// a few days AFTER the purchase date: the seller still gets that coupon
  /// (its record date has passed), so the accrued interest is negative.
  final DateTime? lastInterestDate;
  final double? stampDuty;

  /// Paid back at maturity; the total face value when not given.
  final double? maturityValue;

  /// TDS on each interest payment, in percent.
  final double? tdsRate;
  final String? bondType;
  final DateTime? callDate;

  factory BondTerms.fromFields(Map<String, dynamic> f) => BondTerms(
    faceValue: _num(f[BondKeys.faceValue]),
    units: _num(f[BondKeys.units]),
    couponRate: _num(f[BondKeys.couponRate]) ?? _num(f[BondKeys.legacyRate]),
    frequency: BondFrequency.parse(f[BondKeys.frequency]),
    purchaseDate: _date(f[BondKeys.purchaseDate]),
    maturityDate: _date(f[BondKeys.maturityDate]),
    issuer: '${f[BondKeys.issuer] ?? ''}'.trim(),
    rating: _pick(f[BondKeys.rating], kBondRatings),
    ratingAgency: _pick(f[BondKeys.ratingAgency], kBondRatingAgencies),
    price: _num(f[BondKeys.price]),
    lastInterestDate: _date(f[BondKeys.lastInterestDate]),
    stampDuty: _num(f[BondKeys.stampDuty]),
    maturityValue: _num(f[BondKeys.maturityValue]),
    tdsRate: _num(f[BondKeys.tdsRate]),
    bondType: _pick(f[BondKeys.bondType], kBondTypes),
    callDate: _date(f[BondKeys.callDate]),
  );

  /// The keys to merge into `fields`. Blank optional values are written as
  /// empty strings so a cleared box really clears on both apps.
  Map<String, String> toFields() {
    String d(DateTime? v) => v == null ? '' : isoDate(v);
    return {
      BondKeys.faceValue: _fmt(faceValue),
      BondKeys.units: _fmt(units),
      BondKeys.couponRate: _fmt(couponRate),
      BondKeys.frequency: frequency.label,
      BondKeys.purchaseDate: d(purchaseDate),
      BondKeys.maturityDate: d(maturityDate),
      BondKeys.issuer: issuer.trim(),
      BondKeys.rating: rating ?? '',
      BondKeys.ratingAgency: ratingAgency ?? '',
      BondKeys.price: _fmt(price),
      BondKeys.lastInterestDate: d(lastInterestDate),
      BondKeys.stampDuty: _fmt(stampDuty),
      BondKeys.maturityValue: _fmt(maturityValue),
      BondKeys.tdsRate: _fmt(tdsRate),
      BondKeys.bondType: bondType ?? '',
      BondKeys.callDate: d(callDate),
    };
  }

  static String _fmt(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  /// "CRISIL A", "AAA", or null.
  String? get ratingLabel {
    if (rating == null) return null;
    return ratingAgency == null ? rating : '$ratingAgency $rating';
  }

  /// Total face value, or null when face value / units are not both given.
  double? get faceTotal {
    final f = faceValue, u = units;
    if (f == null || u == null || f <= 0 || u <= 0) return null;
    return f * u;
  }

  /// The date the holder's interest runs from: the last IP date when given,
  /// otherwise the regular coupon date on or before the purchase date.
  DateTime? get accrualStart {
    final start = purchaseDate, end = maturityDate;
    if (start == null || end == null) return null;
    if (frequency.perYear == 0) return start;
    if (lastInterestDate != null) return lastInterestDate;
    final m = frequency.monthsBetween;
    for (var k = 1; k <= 1200; k++) {
      final d = addMonths(end, -k * m);
      if (!d.isAfter(start)) return d;
    }
    return start;
  }

  /// Every coupon date from [accrualStart] (exclusive) to maturity
  /// (inclusive). With a last IP date the schedule runs forward from it, so a
  /// bond paying on the 20th stays on the 20th, and the final payment at
  /// maturity covers the broken period. Otherwise it runs back from maturity.
  List<DateTime> couponDates() {
    final from = accrualStart, end = maturityDate, start = purchaseDate;
    if (from == null || end == null || start == null) return const [];
    if (!end.isAfter(start)) return const [];
    if (frequency.perYear == 0) return [end];
    final m = frequency.monthsBetween;
    final out = <DateTime>[];
    for (var k = 1; k <= 1200; k++) {
      final d = addMonths(from, k * m);
      if (!d.isBefore(end)) break;
      out.add(d);
    }
    out.add(end);
    return out;
  }
}

/// Figures derived from [BondTerms] and the amount invested.
class BondFigures {
  const BondFigures({
    required this.principal,
    required this.consideration,
    required this.accruedAtPurchase,
    required this.accruedDaysAtPurchase,
    required this.costToClient,
    required this.accruedInterest,
    required this.estimatedValue,
    required this.yieldToMaturity,
    required this.yieldToCall,
    required this.payoutPerPeriod,
    required this.nextPayout,
    required this.nextPayoutAmount,
    required this.interestReceived,
    required this.maturityAmount,
    required this.daysToMaturity,
    required this.tdsRate,
  });

  /// Face value the coupon is paid on (face × units, else amount invested).
  final double principal;

  /// Face × price ÷ 100; null without a price.
  final double? consideration;

  /// Interest bought from (positive) or owed to (negative) the seller.
  final double? accruedAtPurchase;
  final int? accruedDaysAtPurchase;

  /// Consideration + accrued interest + stamp duty.
  final double? costToClient;

  /// Interest earned but not yet paid out, as of today.
  final double accruedInterest;

  /// Clean value (the consideration, else the amount invested) plus
  /// [accruedInterest]: the default current value.
  final double estimatedValue;

  /// Annual XIRR (%) from purchase to maturity at the price paid.
  final double? yieldToMaturity;

  /// Annual XIRR (%) if the issuer calls the bond on the call date.
  final double? yieldToCall;

  /// A typical payout (a year's coupon ÷ payouts a year), gross; actual
  /// payouts vary a little with the days in each period. Null for a
  /// cumulative bond.
  final double? payoutPerPeriod;

  final DateTime? nextPayout;

  /// Gross amount of [nextPayout].
  final double? nextPayoutAmount;

  /// Coupons paid since purchase up to today, gross.
  final double interestReceived;

  /// What is paid on the maturity date: maturity value + the last coupon.
  final double? maturityAmount;

  /// Days from today to maturity; 0 once matured, null without a date.
  final int? daysToMaturity;

  /// TDS percent applied to payouts (0 when not set).
  final double tdsRate;

  double net(double gross) => _round2(gross * (1 - tdsRate / 100));

  static BondFigures of(
    BondTerms t, {
    required double invested,
    required DateTime asOf,
  }) {
    final today = _day(asOf);
    final principal = t.faceTotal ?? (invested > 0 ? invested : 0.0);
    final rate = (t.couponRate ?? 0) / 100;
    final cumulative = t.frequency.perYear == 0;
    final start = t.purchaseDate;
    final end = t.maturityDate;
    final redemption = t.maturityValue ?? principal;
    final payouts = _payouts(t, principal, rate);

    // ---- Purchase: consideration, accrued, cost to client ----
    final face = t.faceTotal;
    final consideration = (face != null && t.price != null && t.price! > 0)
        ? face * t.price! / 100
        : null;
    final from = t.accrualStart;
    int? accDays;
    double? accrued0;
    if (start != null && from != null && !cumulative) {
      accDays = _days(from, start);
      accrued0 = principal * rate * accDays / 365;
    }
    final cost = consideration == null
        ? null
        : consideration + (accrued0 ?? 0) + (t.stampDuty ?? 0);

    // ---- Accrued now (actual/365; compounding for cumulative) ----
    var accrued = 0.0;
    if (start != null && end != null && rate > 0 && principal > 0) {
      if (!today.isBefore(end)) {
        accrued = 0; // paid out at maturity
      } else if (cumulative) {
        if (today.isAfter(start)) {
          accrued =
              principal * (math.pow(1 + rate, _days(start, today) / 365) - 1);
        }
      } else if (from != null) {
        var last = from;
        for (final p in payouts) {
          if (!p.date.isAfter(today)) last = p.date;
        }
        accrued = principal * rate * _days(last, today) / 365;
      }
    }

    // ---- Payouts ----
    BondPayout? next;
    var received = 0.0;
    for (final p in payouts) {
      if (p.date.isAfter(today)) {
        next ??= p;
      } else if (start != null && p.date.isAfter(start)) {
        received += p.amount;
      }
    }

    // ---- Maturity ----
    double? maturity;
    if (payouts.isNotEmpty) {
      maturity = cumulative
          ? (t.maturityValue ?? payouts.last.amount)
          : redemption + payouts.last.amount;
    }

    final clean = consideration ?? (invested > 0 ? invested : 0.0);
    final outlay = invested > 0 ? invested : (cost ?? 0);

    return BondFigures(
      principal: principal,
      consideration: consideration == null ? null : _round2(consideration),
      accruedAtPurchase: accrued0 == null ? null : _round2(accrued0),
      accruedDaysAtPurchase: accDays,
      costToClient: cost == null ? null : _round2(cost),
      accruedInterest: _round2(accrued),
      estimatedValue: _round2(clean + accrued),
      yieldToMaturity: _xirr(t, payouts, outlay, redemption, until: end),
      yieldToCall: _yieldToCall(t, principal, rate, outlay),
      payoutPerPeriod: cumulative || principal <= 0
          ? null
          : _round2(principal * rate / t.frequency.perYear),
      nextPayout: next?.date,
      nextPayoutAmount: next == null ? null : _round2(next.amount),
      interestReceived: _round2(received),
      maturityAmount: maturity == null ? null : _round2(maturity),
      daysToMaturity: end == null ? null : math.max(0, _days(today, end)),
      tdsRate: t.tdsRate ?? 0,
    );
  }

  /// The coupons the holder receives, gross. Each pays principal × rate ×
  /// the days in its period ÷ 365, as Indian NCDs do: a 31-day month pays a
  /// little more than a 30-day one, and the stub to maturity (or to a call
  /// date) pays only its days. This is what makes the yield match the deal
  /// sheet's XIRR.
  static List<BondPayout> _payouts(
    BondTerms t,
    double principal,
    double rate, {
    DateTime? stopAt,
  }) {
    final dates = t.couponDates();
    final start = t.purchaseDate;
    if (dates.isEmpty || principal <= 0 || start == null) return const [];
    if (t.frequency.perYear == 0) {
      final end = stopAt ?? dates.last;
      final years = _days(start, end) / 365;
      return [BondPayout(end, principal * math.pow(1 + rate, years))];
    }
    final out = <BondPayout>[];
    var prev = t.accrualStart!;
    for (final d in dates) {
      final pay = (stopAt != null && d.isAfter(stopAt)) ? stopAt : d;
      out.add(BondPayout(pay, principal * rate * _days(prev, pay) / 365));
      if (pay != d) break;
      prev = d;
    }
    return out;
  }

  static double? _yieldToCall(
    BondTerms t,
    double principal,
    double rate,
    double outlay,
  ) {
    final call = t.callDate, start = t.purchaseDate, end = t.maturityDate;
    if (call == null || start == null || end == null) return null;
    if (!call.isAfter(start) || !call.isBefore(end)) return null;
    final flows = _payouts(t, principal, rate, stopAt: call);
    return _xirr(t, flows, outlay, principal, until: call);
  }

  /// XIRR: the annual rate at which the payouts plus the redemption on
  /// [until] are worth exactly [outlay] on the purchase date. Bisection, so
  /// it never diverges; null when there is nothing to solve.
  static double? _xirr(
    BondTerms t,
    List<BondPayout> payouts,
    double outlay,
    double redemption, {
    required DateTime? until,
  }) {
    final start = t.purchaseDate;
    if (start == null || until == null || !until.isAfter(start)) return null;
    if (outlay <= 0 || payouts.isEmpty || t.couponRate == null) return null;
    final cumulative = t.frequency.perYear == 0;
    final flows = <(double, double)>[
      for (final p in payouts)
        if (p.date.isAfter(start))
          (_days(start, p.date) / 365, cumulative ? 0.0 : p.amount),
      (
        _days(start, until) / 365,
        cumulative ? (t.maturityValue ?? payouts.last.amount) : redemption,
      ),
    ];

    double pv(double y) {
      var s = 0.0;
      for (final (yr, amt) in flows) {
        s += amt / math.pow(1 + y, yr);
      }
      return s;
    }

    var lo = -0.99, hi = 5.0;
    if (pv(lo) < outlay || pv(hi) > outlay) return null;
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      if (pv(mid) > outlay) {
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

  /// Optional, but above zero when given.
  static String? positiveOptional(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n <= 0) return 'Enter a number above 0';
    return null;
  }

  /// Optional, zero or more.
  static String? nonNegativeOptional(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n < 0) return 'Enter 0 or more';
    return null;
  }

  /// Price per ₹100 of face value, optional.
  static String? price(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n <= 0 || n > 200) {
      return 'Price per ₹100, e.g. 102';
    }
    return null;
  }

  static String? tdsRate(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n < 0 || n > 50) {
      return 'Use a rate between 0 and 50%';
    }
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

  /// Optional. Must be the interest date nearest the purchase: no more than
  /// one payout period either side of it, and before maturity.
  static String? lastInterestDate(
    DateTime? d, {
    required DateTime? purchase,
    required DateTime? maturity,
    required BondFrequency frequency,
  }) {
    if (d == null || purchase == null) return null;
    if (frequency.perYear == 0) return null;
    if (maturity != null && !d.isBefore(maturity)) {
      return 'Must be before maturity';
    }
    final m = frequency.monthsBetween;
    if (d.isBefore(addMonths(purchase, -m)) ||
        d.isAfter(addMonths(purchase, m))) {
      return 'Use the interest date nearest the purchase';
    }
    return null;
  }

  static String? callDate(
    DateTime? d, {
    required DateTime? purchase,
    required DateTime? maturity,
  }) {
    if (d == null) return null;
    if (purchase != null && !d.isAfter(purchase)) {
      return 'Must be after the purchase date';
    }
    if (maturity != null && !d.isBefore(maturity)) {
      return 'Must be before maturity';
    }
    return null;
  }
}
