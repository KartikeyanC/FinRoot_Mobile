import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import 'investment.dart';
import 'live_price.dart';
import 'stock_lots.dart';

/// One row of the holdings list, worked out once: a single holding or a
/// stock bought several times, with the figures the row and its detail
/// sheet show. Pure — no widgets, no providers.
class HoldingFigures {
  const HoldingFigures({
    required this.name,
    required this.asset,
    required this.currency,
    required this.symbol,
    required this.qty,
    required this.avgPrice,
    required this.livePrice,
    required this.invested,
    required this.current,
    required this.lots,
  });

  final String name;
  final String asset;
  final String currency;

  /// The live-price ticker ("ITC.NS"), null when none is set.
  final String? symbol;

  /// 0 when the holding does not say (an amount-only holding).
  final double qty;
  final double avgPrice;
  final double? livePrice;
  final double invested;

  /// Live value when priced, else the stored current value.
  final double current;

  /// One lot for a single holding; every purchase, oldest first, for a group.
  final List<Lot> lots;

  double get gain => current - invested;
  bool get up => gain >= 0;
  bool get isGroup => lots.length > 1;
  InvestmentRecord get record => lots.first.record;

  /// Return on what was paid — the same as the live price against the
  /// average price. Null when nothing was invested.
  double? get returnPct => invested > 0 ? gain / invested * 100 : null;
}

HoldingFigures figuresFor(PortfolioItem item, Map<String, double> prices) =>
    switch (item) {
      SingleHolding(:final record) => _single(record, prices),
      GroupedHolding(:final group) => _group(group, prices),
    };

HoldingFigures _single(InvestmentRecord r, Map<String, double> prices) {
  final lot = toLot(r);
  return HoldingFigures(
    name: r.name,
    asset: r.asset,
    currency: r.currency,
    symbol: resolveLiveSymbol(r)?.symbol,
    qty: lot.qty,
    avgPrice: lot.qty > 0 ? lot.price : 0,
    livePrice: liveFor(r, prices)?.unitPrice,
    invested: r.invested.amount.toDouble(),
    current: effectiveCurrent(r, prices),
    lots: [lot],
  );
}

HoldingFigures _group(StockGroup g, Map<String, double> prices) {
  final first = g.lots.first.record;
  return HoldingFigures(
    name: g.name,
    asset: first.asset,
    currency: g.currency,
    symbol: resolveLiveSymbol(first)?.symbol,
    qty: g.qty,
    avgPrice: g.avgPrice,
    livePrice: g.lots
        .map((l) => liveFor(l.record, prices)?.unitPrice)
        .firstWhere((p) => p != null, orElse: () => null),
    invested: g.invested,
    current: groupCurrent(g, prices),
    lots: g.lots,
  );
}

/// "4,380.00" — two decimals and Indian grouping, no symbol, for rupees:
/// the broker-list style, where every figure lines up. Other currencies keep
/// their symbol ("$1,204.50") so they are never mistaken for rupees.
String plainAmount(double v, String currency) {
  if (currency == 'INR') {
    return NumberFormat('#,##,##0.00', 'en_IN').format(v);
  }
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: currencySymbol(currency),
    decimalDigits: 2,
  ).format(v);
}

/// "+280.00" / "-290.00".
String signedAmount(double v, String currency) =>
    v < 0 ? '-${plainAmount(-v, currency)}' : '+${plainAmount(v, currency)}';

/// "+6.83%" / "-5.92%"; an em dash when there is nothing to compare with.
String signedPct(double? pct) => pct == null
    ? '—'
    : '${pct < 0 ? '' : '+'}${pct.toStringAsFixed(2)}%';

/// "10" / "2.5" — whole quantities without decimals.
String qtyLabel(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
