// Search-by-name for the holding form - the port of the web's
// `src/lib/symbolSearch.ts`. A name is looked up through the `live-price`
// function's `search` request; picking a hit writes the ticker the live-price
// path understands.

class SymbolHit {
  const SymbolHit({
    required this.ticker,
    required this.name,
    required this.exchange,
  });

  /// What goes in the holding: `NSE:RELIANCE`, or a scheme code.
  final String ticker;
  final String name;

  /// "NSE", "NASDAQ"; empty for funds.
  final String exchange;
}

const int minSymbolQuery = 2;
const int maxSymbolResults = 8;

const Map<String, String> _suffixToPrefix = {
  '.NS': 'NSE',
  '.BO': 'BOM',
  '.L': 'LSE',
  '.T': 'TSE',
  '.TO': 'TSX',
  '.AX': 'ASX',
  '.HK': 'HKG',
  '.F': 'FRA',
  '.PA': 'EPA',
};

const Map<String, String> _usExchangePrefix = {
  'NMS': 'NASDAQ',
  'NGM': 'NASDAQ',
  'NCM': 'NASDAQ',
  'NAS': 'NASDAQ',
  'NYQ': 'NYSE',
  'ASE': 'AMEX',
};

/// `RELIANCE.NS` becomes `NSE:RELIANCE`; `AAPL` on NMS becomes `NASDAQ:AAPL`.
String yahooToTicker(String symbol, [String? exchange]) {
  final sym = symbol.trim().toUpperCase();
  final dot = sym.lastIndexOf('.');
  if (dot > 0) {
    final prefix = _suffixToPrefix[sym.substring(dot)];
    return prefix != null ? '$prefix:${sym.substring(0, dot)}' : sym;
  }
  final us = exchange == null ? null : _usExchangePrefix[exchange.toUpperCase()];
  return us != null ? '$us:$sym' : sym;
}

/// One raw result of the function as a hit, or null when it cannot be one.
/// [provider] is `mf` or `yahoo`; crypto is searched as `yahoo` and keeps the
/// raw Yahoo pair (`BTC-USD`).
SymbolHit? toSymbolHit(String provider, Object? raw, {bool crypto = false}) {
  if (raw is! Map) return null;
  final symbol = '${raw['symbol'] ?? ''}'.trim();
  final name = '${raw['name'] ?? ''}'.trim();
  if (symbol.isEmpty || name.isEmpty) return null;
  if (provider == 'mf') {
    return RegExp(r'^\d{4,}$').hasMatch(symbol)
        ? SymbolHit(ticker: symbol, name: name, exchange: '')
        : null;
  }
  final type = raw['type'] is String ? raw['type'] as String : null;
  final exchange = '${raw['exchange'] ?? ''}';
  if (crypto) {
    if (type != null && type != 'CRYPTOCURRENCY') return null;
    return SymbolHit(
      ticker: symbol.toUpperCase(),
      name: name,
      exchange: exchange,
    );
  }
  if (type != null && type != 'EQUITY' && type != 'ETF') return null;
  return SymbolHit(
    ticker: yahooToTicker(symbol, exchange),
    name: name,
    exchange: exchange,
  );
}

List<SymbolHit> parseSymbolHits(
  String provider,
  Object? data, {
  bool crypto = false,
}) {
  final results = data is Map ? data['results'] : null;
  if (results is! List) return const [];
  final out = <SymbolHit>[];
  for (final r in results) {
    final h = toSymbolHit(provider, r, crypto: crypto);
    if (h != null) out.add(h);
    if (out.length >= maxSymbolResults) break;
  }
  return out;
}
