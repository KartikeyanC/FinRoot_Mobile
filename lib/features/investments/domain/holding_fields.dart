import 'investment.dart';

/// Which `fields` keys a holding's ticker and quantity live under - the SAME
/// keys the web reads and writes (`pickTicker` / `getQuantity` in
/// `src/lib/livePrices.ts`), so a holding edited on either device keeps
/// getting priced.
///
/// * stocks / crypto: ticker in `ticker`, units in `qty` (or `quantity`)
/// * mutual funds: MFAPI scheme code in `scheme`, units in `units`

/// Asset classes the `live-price` function can price.
bool isPriceableAsset(String asset) =>
    asset == 'stocks' || asset == 'crypto' || asset == 'mutual_funds';

/// Every key a ticker can be stored under (read order of the web).
const List<String> kTickerKeys = ['ticker', 'symbol', 'coin', 'scheme'];

/// Every key a quantity can be stored under.
const List<String> kQuantityKeys = ['quantity', 'qty', 'units'];

String _text(Object? v) {
  if (v == null) return '';
  if (v is num) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  return '$v'.trim();
}

/// The ticker a record is currently saved with (what the form pre-fills).
String tickerTextOf(InvestmentRecord r) {
  for (final k in kTickerKeys) {
    final t = _text(r.fields[k]);
    if (t.isNotEmpty) return t;
  }
  return '';
}

/// The units a record is saved with, for the form; empty when none or zero.
String quantityTextOf(InvestmentRecord r) {
  final keys = r.asset == 'mutual_funds'
      ? const ['units']
      : const ['quantity', 'qty'];
  for (final k in keys) {
    final t = _text(r.fields[k]);
    final n = double.tryParse(t);
    if (t.isNotEmpty && n != null && n != 0) return t;
  }
  return '';
}

/// Normalises what was typed into a ticker. Stocks and crypto are upper-cased
/// with no spaces (`nse:itc` becomes `NSE:ITC`); a fund's scheme code is kept.
String normalizeTicker(String asset, String raw) {
  final t = raw.trim();
  if (asset == 'mutual_funds') return t;
  return t.toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

/// The `fields` map to save: the holding's existing [base] (web-written keys
/// are kept untouched) plus the mobile figures and, for priceable assets, the
/// ticker and quantity under the web's keys. A blank ticker or quantity
/// removes the keys so a cleared box really clears.
Map<String, dynamic> buildHoldingFields({
  Map<String, dynamic> base = const {},
  required String asset,
  required String name,
  required String invested,
  required String current,
  String ticker = '',
  String quantity = '',
}) {
  final out = <String, dynamic>{
    ...base,
    'name': name.trim(),
    'invested': invested,
    'current': current,
    '_mobile': '1',
  };
  if (!isPriceableAsset(asset)) return out;

  for (final k in kTickerKeys) {
    out.remove(k);
  }
  final t = normalizeTicker(asset, ticker);
  final isFund = asset == 'mutual_funds';
  if (t.isNotEmpty) out[isFund ? 'scheme' : 'ticker'] = t;

  // A record that already used `quantity` keeps that key; otherwise the web's
  // own `qty` / `units`.
  final useQuantityKey =
      !isFund && base.containsKey('quantity') && !base.containsKey('qty');
  for (final k in kQuantityKeys) {
    out.remove(k);
  }
  final q = quantity.trim();
  if (q.isNotEmpty) {
    out[isFund ? 'units' : (useQuantityKey ? 'quantity' : 'qty')] = q;
  }
  return out;
}
