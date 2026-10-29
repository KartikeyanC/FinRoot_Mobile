import 'package:intl/intl.dart';

/// Price alerts — the mobile port of the web's `src/lib/priceAlerts.ts`.
///
/// "Tell me when ITC.NS falls to ₹260." An alert holds a stock, a target and
/// which side of the target counts, and fires ONCE when a live price crosses
/// it; it then stays triggered (with the price that tripped it) until re-armed
/// or deleted. Stored per workspace in `tenant_settings` under `price_alerts`,
/// shared with the web dashboard and the Windows app, so the JSON written here
/// must keep the web's shape: {id, symbol, name, target, direction,
/// createdAt, triggeredAt, triggeredPrice}.

enum AlertDirection { below, above }

class PriceAlert {
  const PriceAlert({
    required this.id,
    required this.symbol,
    required this.name,
    required this.target,
    required this.direction,
    required this.createdAt,
    this.triggeredAt,
    this.triggeredPrice,
  });

  final String id;

  /// Yahoo symbol as the live-price function prices it: RELIANCE.NS, AAPL.
  final String symbol;
  final String name;
  final double target;
  final AlertDirection direction;
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final double? triggeredPrice;

  bool get isActive => triggeredAt == null;

  /// The key the live-price function answers with.
  String get priceKey => 'yahoo:$symbol';

  PriceAlert triggered(double price, DateTime at) => PriceAlert(
    id: id,
    symbol: symbol,
    name: name,
    target: target,
    direction: direction,
    createdAt: createdAt,
    triggeredAt: at,
    triggeredPrice: price,
  );

  PriceAlert rearmed() => PriceAlert(
    id: id,
    symbol: symbol,
    name: name,
    target: target,
    direction: direction,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'symbol': symbol,
    'name': name,
    'target': target,
    'direction': direction.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'triggeredAt': triggeredAt?.toUtc().toIso8601String(),
    'triggeredPrice': triggeredPrice,
  };

  /// Tolerant read; null for a row the web would also drop.
  static PriceAlert? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final symbol = raw['symbol'];
    if (id is! String || symbol is! String) return null;
    final target = raw['target'] is num
        ? (raw['target'] as num).toDouble()
        : double.tryParse('${raw['target']}');
    if (target == null || !target.isFinite || target <= 0) return null;
    final direction = switch (raw['direction']) {
      'below' => AlertDirection.below,
      'above' => AlertDirection.above,
      _ => null,
    };
    if (direction == null) return null;
    final sym = normaliseSymbol(symbol);
    final name = raw['name'];
    final trigPrice = raw['triggeredPrice'];
    return PriceAlert(
      id: id,
      symbol: sym,
      name: name is String && name.isNotEmpty ? name : sym,
      target: target,
      direction: direction,
      createdAt:
          DateTime.tryParse('${raw['createdAt']}') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      triggeredAt: raw['triggeredAt'] is String
          ? DateTime.tryParse(raw['triggeredAt'] as String)
          : null,
      triggeredPrice: trigPrice is num ? trigPrice.toDouble() : null,
    );
  }
}

/// Matches the web's MAX_ALERTS.
const maxAlerts = 50;

String normaliseSymbol(String raw) =>
    raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

final _symbolPattern = RegExp(r'^[A-Z0-9][A-Z0-9&.=^-]{0,24}$');

List<PriceAlert> parseStoredAlerts(Object? raw) {
  if (raw is! List) return const [];
  return [for (final item in raw) ?PriceAlert.fromJson(item)];
}

bool isHit(AlertDirection direction, double target, double price) {
  if (!price.isFinite || price <= 0) return false;
  return direction == AlertDirection.below ? price <= target : price >= target;
}

List<String> activeSymbols(List<PriceAlert> alerts) =>
    {for (final a in alerts.where((a) => a.isActive)) a.symbol}.toList();

class AlertRound {
  const AlertRound(this.next, this.fired);
  final List<PriceAlert> next;
  final List<PriceAlert> fired;
}

/// One round of live prices: newly-hit alerts become triggered. An alert with
/// no price this round is left alone — a failed lookup is not a hit.
AlertRound evaluateAlerts(
  List<PriceAlert> alerts,
  Map<String, double> prices,
  DateTime now,
) {
  final fired = <PriceAlert>[];
  final next = [
    for (final a in alerts)
      if (a.isActive &&
          prices[a.priceKey] != null &&
          isHit(a.direction, a.target, prices[a.priceKey]!))
        () {
          final hit = a.triggered(prices[a.priceKey]!, now);
          fired.add(hit);
          return hit;
        }()
      else
        a,
  ];
  return AlertRound(next, fired);
}

/// Null when fine, otherwise a message for the form. Same rules as the web.
String? validateAlert({
  required String symbol,
  required String target,
  required AlertDirection direction,
  List<PriceAlert> existing = const [],
}) {
  final sym = normaliseSymbol(symbol);
  if (sym.isEmpty) return 'Type the stock\'s ticker, for example ITC.NS.';
  if (!_symbolPattern.hasMatch(sym)) {
    return 'That does not look like a ticker (for example RELIANCE.NS or AAPL).';
  }
  final t = double.tryParse(target.trim());
  if (t == null || !t.isFinite || t <= 0) {
    return 'Enter the price you want to be alerted at.';
  }
  if (existing.where((a) => a.isActive).length >= maxAlerts) {
    return 'You can watch up to $maxAlerts prices at once.';
  }
  final dup = existing.any(
    (a) =>
        a.isActive &&
        a.symbol == sym &&
        a.direction == direction &&
        a.target == t,
  );
  if (dup) return 'You already have this alert.';
  return null;
}

/// "₹" for Indian listings, "$" for bare US tickers, nothing otherwise.
String currencySymbol(String symbol) {
  if (RegExp(r'\.(NS|BO)$').hasMatch(symbol)) return '₹';
  if (!symbol.contains('.')) return r'$';
  return '';
}

String formatPrice(String symbol, double value) {
  final cur = currencySymbol(symbol);
  final f = NumberFormat.decimalPatternDigits(
    locale: cur == '₹' ? 'en_IN' : 'en_US',
    decimalDigits: 0,
  )..maximumFractionDigits = 2;
  return '$cur${f.format(value)}';
}

String describeAlert(PriceAlert a) {
  final verb = a.direction == AlertDirection.below ? 'falls to' : 'rises to';
  final tail = a.direction == AlertDirection.below ? 'or below' : 'or above';
  return '${a.name} $verb ${formatPrice(a.symbol, a.target)} $tail';
}

/// Percentage the price still has to move; 0 or less means reached.
double distanceToTarget(PriceAlert a, double price) {
  if (!price.isFinite || price <= 0) return double.nan;
  final gap = a.direction == AlertDirection.below
      ? price - a.target
      : a.target - price;
  return gap / price * 100;
}

/// Notification text — identical to the web's `firedMessage`.
({String title, String body}) firedMessage(PriceAlert a) {
  final at = formatPrice(a.symbol, a.triggeredPrice ?? a.target);
  final target = formatPrice(a.symbol, a.target);
  final side = a.direction == AlertDirection.below
      ? 'at or below your $target buy price'
      : 'at or above your $target target';
  return (title: 'Price alert: ${a.name}', body: '${a.symbol} is at $at, $side.');
}
