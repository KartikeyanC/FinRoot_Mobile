import 'investment.dart';
import 'live_price.dart';

/// Several purchases of one stock are one holding — the mobile port of the
/// web's `src/lib/stockLots.ts`. Each purchase stays its own record (date,
/// quantity, price); the list shows purchases of the same stock as ONE tile
/// with the total quantity and the weighted average price. Same rules on both
/// sides: same priced symbol + currency, name as the fallback.

/// Null = never merged (not a stock, or no ticker and no name).
String? lotKey(InvestmentRecord r) {
  if (r.asset != 'stocks') return null;
  final symbol = resolveLiveSymbol(r)?.symbol ?? '';
  final name = '${r.fields['name'] ?? ''}'.trim().toUpperCase();
  final id = symbol.isNotEmpty ? symbol : name;
  return id.isEmpty ? null : '$id|${r.currency}';
}

double _num(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

class Lot {
  const Lot({
    required this.record,
    required this.date,
    required this.qty,
    required this.price,
    required this.invested,
  });

  final InvestmentRecord record;

  /// The purchase date (`buy_date`), else the day the record was saved.
  final DateTime? date;

  /// 0 when the record does not say (a holding added on the phone stores
  /// amounts only).
  final double qty;
  final double price;
  final double invested;
}

DateTime? _buyDate(InvestmentRecord r) {
  final raw = '${r.fields['buy_date'] ?? ''}';
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)
      ? DateTime.tryParse(raw)
      : r.savedAt?.toLocal();
}

Lot toLot(InvestmentRecord r) {
  final qty = _num(r.fields['qty']) != 0
      ? _num(r.fields['qty'])
      : _num(r.fields['quantity']);
  final invested = r.invested.amount.toDouble();
  final buy = _num(r.fields['buy']);
  return Lot(
    record: r,
    date: _buyDate(r),
    qty: qty,
    price: buy != 0 ? buy : (qty > 0 ? invested / qty : 0),
    invested: invested,
  );
}

class StockGroup {
  const StockGroup({
    required this.key,
    required this.name,
    required this.lots,
  });

  final String key;
  final String name;

  /// Oldest purchase first.
  final List<Lot> lots;

  String get currency => lots.first.record.currency;
  double get qty => lots.fold(0, (s, l) => s + l.qty);
  double get invested => lots.fold(0, (s, l) => s + l.invested);

  /// Weighted: total invested ÷ total quantity; 0 when no quantity is known.
  double get avgPrice => qty > 0 ? invested / qty : 0;
}

StockGroup summarise(String key, List<InvestmentRecord> records) {
  final lots = records.map(toLot).toList()
    ..sort((a, b) {
      final x = a.date, y = b.date;
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    });
  final named = records
      .map((r) => '${r.fields['name'] ?? ''}'.trim())
      .firstWhere((n) => n.isNotEmpty, orElse: () => records.first.name);
  return StockGroup(key: key, name: named, lots: lots);
}

sealed class PortfolioItem {
  const PortfolioItem();
}

class SingleHolding extends PortfolioItem {
  const SingleHolding(this.record);
  final InvestmentRecord record;
}

class GroupedHolding extends PortfolioItem {
  const GroupedHolding(this.group);
  final StockGroup group;
}

/// A stock bought more than once becomes one group, placed where its first
/// record sat; everything else stays a single row, in order.
List<PortfolioItem> groupPortfolio(List<InvestmentRecord> records) {
  final byKey = <String, List<InvestmentRecord>>{};
  for (final r in records) {
    final k = lotKey(r);
    if (k != null) (byKey[k] ??= []).add(r);
  }
  final placed = <String>{};
  final out = <PortfolioItem>[];
  for (final r in records) {
    final k = lotKey(r);
    final lots = k == null ? null : byKey[k];
    if (k == null || lots == null || lots.length < 2) {
      out.add(SingleHolding(r));
    } else if (placed.add(k)) {
      out.add(GroupedHolding(summarise(k, lots)));
    }
  }
  return out;
}

/// Current value: each purchase's live value when priced, else its stored one.
double groupCurrent(StockGroup g, Map<String, double> prices) => g.lots.fold(
  0,
  (s, l) => s + (liveFor(l.record, prices)?.value ?? l.record.current.amount.toDouble()),
);
