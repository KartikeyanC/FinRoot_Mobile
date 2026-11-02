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

  /// Price alerts watch Yahoo tickers, so only stocks and crypto can have
  /// one — a fund's NAV or a deposit never would fire.
  bool get canAlert => asset == 'stocks' || asset == 'crypto';
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

/// The asset type of a list row ("stocks", "mutual_funds", …).
String assetOf(PortfolioItem item) => switch (item) {
  SingleHolding(:final record) => record.asset,
  GroupedHolding(:final group) => group.lots.first.record.asset,
};

/// Every record behind a list row: one, or each purchase of a group.
Iterable<InvestmentRecord> recordsOf(PortfolioItem item) => switch (item) {
  SingleHolding(:final record) => [record],
  GroupedHolding(:final group) => group.lots.map((l) => l.record),
};

/// The asset types present, each with how many rows it has, in the app's
/// usual order (Stocks, Mutual Funds, Bonds, …; anything unknown last).
List<({String asset, int count})> assetBreakdown(List<PortfolioItem> items) {
  final counts = <String, int>{};
  for (final i in items) {
    counts.update(assetOf(i), (n) => n + 1, ifAbsent: () => 1);
  }
  final order = kAssetLabels.keys.toList();
  int rank(String a) {
    final i = order.indexOf(a);
    return i < 0 ? order.length : i;
  }

  return [
    for (final a in counts.keys.toList()
      ..sort((x, y) => rank(x).compareTo(rank(y))))
      (asset: a, count: counts[a]!),
  ];
}
