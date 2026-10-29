import 'investment.dart';

/// Live market prices for holdings — the mobile port of the web's
/// `src/lib/livePrices.ts` (`resolveSymbol`, `getQuantity`, `cacheKey`).
/// Keep the two in step: both ask the same `live-price` edge function, and a
/// holding must resolve to the same symbol on either device.

/// `yahoo` prices stocks and crypto; `mf` prices a mutual fund's NAV.
enum LiveProvider { yahoo, mf }

class LiveWant {
  const LiveWant(this.provider, this.symbol);
  final LiveProvider provider;
  final String symbol;

  String get key => liveKey(provider, symbol);

  Map<String, String> toJson() => {'provider': provider.name, 'symbol': symbol};

  @override
  bool operator ==(Object other) =>
      other is LiveWant && other.provider == provider && other.symbol == symbol;

  @override
  int get hashCode => Object.hash(provider, symbol);
}

/// Same key the function answers with: `yahoo:RELIANCE.NS`, `mf:119551`.
String liveKey(LiveProvider provider, String symbol) =>
    '${provider.name}:$symbol';

/// Google-Finance style prefixes the web dialog used to write (`NSE:ITC`).
const Map<String, String> _yahooSuffix = {
  'NSE': '.NS',
  'BSE': '.BO',
  'BOM': '.BO',
  'NASDAQ': '',
  'NYSE': '',
  'AMEX': '',
  'LSE': '.L',
  'TSE': '.T',
  'TSX': '.TO',
  'ASX': '.AX',
  'HKG': '.HK',
  'FRA': '.F',
  'EPA': '.PA',
};

/// Which symbol a holding is priced under, or null when it has none (an FD,
/// gold, or a stock saved without a ticker).
LiveWant? resolveLiveSymbol(InvestmentRecord r) {
  final f = r.fields;
  final raw = '${f['ticker'] ?? f['symbol'] ?? f['coin'] ?? f['scheme'] ?? ''}'
      .trim();
  if (raw.isEmpty) return null;

  switch (r.asset) {
    case 'mutual_funds':
      final m = RegExp(r'(\d{4,})').firstMatch(raw);
      return m == null ? null : LiveWant(LiveProvider.mf, m.group(1)!);
    case 'crypto':
      final sym = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      return LiveWant(LiveProvider.yahoo, sym.contains('-') ? sym : '$sym-USD');
    case 'stocks':
      var sym = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      if (sym.contains(':')) {
        final parts = sym.split(':');
        sym = parts[1] + (_yahooSuffix[parts[0]] ?? '');
      }
      return LiveWant(LiveProvider.yahoo, sym);
    default:
      return null;
  }
}

double _num(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// Units held, or 0 when the record does not say (a mobile-written holding
/// stores amounts only) — then only the unit price can be shown live.
double liveQuantity(InvestmentRecord r) {
  final f = r.fields;
  return switch (r.asset) {
    'stocks' || 'crypto' => _num(f['quantity']) != 0
        ? _num(f['quantity'])
        : _num(f['qty']),
    'mutual_funds' => _num(f['units']),
    _ => 0,
  };
}

/// The deduped set of symbols that prices [records].
List<LiveWant> liveWantsFor(Iterable<InvestmentRecord> records) {
  final out = <LiveWant>{};
  for (final r in records) {
    final w = resolveLiveSymbol(r);
    if (w != null) out.add(w);
  }
  return out.toList();
}

/// A holding's live figures, when its symbol came back priced.
class LiveHolding {
  const LiveHolding({required this.unitPrice, required this.quantity});
  final double unitPrice;
  final double quantity;

  /// Null when the quantity is unknown.
  double? get value => quantity > 0 ? unitPrice * quantity : null;
}

LiveHolding? liveFor(InvestmentRecord r, Map<String, double> prices) {
  final want = resolveLiveSymbol(r);
  if (want == null) return null;
  final price = prices[want.key];
  if (price == null || !price.isFinite || price <= 0) return null;
  return LiveHolding(unitPrice: price, quantity: liveQuantity(r));
}
