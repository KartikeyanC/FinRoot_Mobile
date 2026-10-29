import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/domain/live_price.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _rec(String asset, Map<String, dynamic> fields) => InvestmentRecord(
  id: 'r-${fields.hashCode}',
  asset: asset,
  currency: 'INR',
  fields: fields,
  derived: const {},
);

void main() {
  group('resolveLiveSymbol matches the web resolveSymbol', () {
    test('stocks: Yahoo symbols pass through, old prefixes map to suffixes', () {
      expect(resolveLiveSymbol(_rec('stocks', {'ticker': 'ITC.NS'}))?.key, 'yahoo:ITC.NS');
      expect(resolveLiveSymbol(_rec('stocks', {'ticker': 'NSE:RELIANCE'}))?.key, 'yahoo:RELIANCE.NS');
      expect(resolveLiveSymbol(_rec('stocks', {'ticker': 'nasdaq:aapl'}))?.key, 'yahoo:AAPL');
      expect(resolveLiveSymbol(_rec('stocks', {'ticker': 'BOM:500325'}))?.key, 'yahoo:500325.BO');
    });

    test('funds use the scheme code, crypto gets -USD', () {
      expect(resolveLiveSymbol(_rec('mutual_funds', {'scheme': 'Axis 119551'}))?.key, 'mf:119551');
      expect(resolveLiveSymbol(_rec('crypto', {'coin': 'btc'}))?.key, 'yahoo:BTC-USD');
    });

    test('no ticker, or an asset with no market price, resolves to nothing', () {
      expect(resolveLiveSymbol(_rec('stocks', {'name': 'Infosys'})), isNull);
      expect(resolveLiveSymbol(_rec('fd', {'ticker': 'X'})), isNull);
      expect(resolveLiveSymbol(_rec('mutual_funds', {'scheme': 'no code'})), isNull);
    });
  });

  test('liveWantsFor dedupes two holdings of the same stock', () {
    final wants = liveWantsFor([
      _rec('stocks', {'ticker': 'ITC.NS', 'quantity': '10'}),
      _rec('stocks', {'ticker': 'NSE:ITC', 'quantity': '5'}),
      _rec('gold', {'grams': '10'}),
    ]);
    expect(wants.map((w) => w.key), ['yahoo:ITC.NS']);
  });

  test('liveFor gives a live value when the quantity is known', () {
    final prices = {'yahoo:ITC.NS': 265.0};
    final held = liveFor(_rec('stocks', {'ticker': 'ITC.NS', 'quantity': '10'}), prices)!;
    expect(held.unitPrice, 265);
    expect(held.value, 2650);

    final noQty = liveFor(_rec('stocks', {'ticker': 'ITC.NS'}), prices)!;
    expect(noQty.value, isNull);

    expect(liveFor(_rec('stocks', {'ticker': 'AAPL'}), prices), isNull);
  });
}
