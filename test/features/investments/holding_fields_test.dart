import 'package:finroot_mobile/features/investments/data/live_price_gateway.dart';
import 'package:finroot_mobile/features/investments/domain/holding_fields.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/domain/live_price.dart';
import 'package:finroot_mobile/features/investments/domain/symbol_search.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _rec(String asset, Map<String, dynamic> f) => InvestmentRecord(
  id: 'x',
  asset: asset,
  currency: 'INR',
  fields: f,
  derived: const {},
);

Map<String, dynamic> _build(
  String asset, {
  Map<String, dynamic> base = const {},
  String ticker = '',
  String quantity = '',
}) => buildHoldingFields(
  base: base,
  asset: asset,
  name: ' ITC ',
  invested: '100',
  current: '120',
  ticker: ticker,
  quantity: quantity,
);

void main() {
  test('stocks write ticker + qty and resolve to a live symbol', () {
    final f = _build('stocks', ticker: 'nse:itc', quantity: '10');
    expect(f['ticker'], 'NSE:ITC');
    expect(f['qty'], '10');
    expect(f['name'], 'ITC');
    expect(f['_mobile'], '1');
    final r = _rec('stocks', f);
    expect(resolveLiveSymbol(r)?.symbol, 'ITC.NS');
    expect(liveQuantity(r), 10);
  });

  test('mutual funds write scheme + units', () {
    final f = _build('mutual_funds', ticker: '119551', quantity: '25.5');
    expect(f['scheme'], '119551');
    expect(f['units'], '25.5');
    final r = _rec('mutual_funds', f);
    expect(resolveLiveSymbol(r)?.key, 'mf:119551');
    expect(liveQuantity(r), 25.5);
  });

  test('crypto writes ticker + qty', () {
    final f = _build('crypto', ticker: 'btc', quantity: '0.5');
    expect(f['ticker'], 'BTC');
    expect(resolveLiveSymbol(_rec('crypto', f))?.symbol, 'BTC-USD');
  });

  test('editing keeps web-written keys and swaps alias keys', () {
    final f = _build(
      'stocks',
      base: {'symbol': 'OLD', 'buy': '90', 'buy_date': '2024-01-02', 'quantity': 4},
      ticker: 'ITC.NS',
      quantity: '6',
    );
    expect(f['buy'], '90');
    expect(f['buy_date'], '2024-01-02');
    expect(f.containsKey('symbol'), false);
    expect(f['ticker'], 'ITC.NS');
    expect(f['quantity'], '6');
    expect(f.containsKey('qty'), false);
  });

  test('blank ticker and quantity clear the keys; other assets untouched', () {
    final cleared = _build(
      'stocks',
      base: {'ticker': 'ITC.NS', 'qty': '3'},
    );
    expect(cleared.containsKey('ticker'), false);
    expect(cleared.containsKey('qty'), false);
    final gold = _build('gold', base: {'grams': '5'}, ticker: 'X', quantity: '1');
    expect(gold.containsKey('ticker'), false);
    expect(gold['grams'], '5');
  });

  test('form prefill reads the same keys', () {
    expect(tickerTextOf(_rec('crypto', {'coin': 'eth'})), 'eth');
    expect(quantityTextOf(_rec('stocks', {'qty': 7})), '7');
    expect(quantityTextOf(_rec('mutual_funds', {'units': '1.5'})), '1.5');
    expect(quantityTextOf(_rec('stocks', {})), '');
  });

  test('validators are optional but strict when filled', () {
    expect(InvestmentValidators.ticker('', asset: 'stocks'), isNull);
    expect(InvestmentValidators.ticker('abc', asset: 'mutual_funds'), isNotNull);
    expect(InvestmentValidators.ticker('119551', asset: 'mutual_funds'), isNull);
    expect(InvestmentValidators.quantity(''), isNull);
    expect(InvestmentValidators.quantity('0'), isNotNull);
    expect(InvestmentValidators.quantity('abc'), isNotNull);
    expect(InvestmentValidators.quantity('2.5'), isNull);
  });

  test('symbol search maps Yahoo and MFAPI hits like the web', () {
    expect(yahooToTicker('RELIANCE.NS'), 'NSE:RELIANCE');
    expect(yahooToTicker('AAPL', 'NMS'), 'NASDAQ:AAPL');
    final hits = parseSymbolHits('yahoo', {
      'results': [
        {'symbol': 'RELIANCE.NS', 'name': 'Reliance', 'exchange': 'NSI', 'type': 'EQUITY'},
        {'symbol': 'XYZ', 'name': 'Option', 'type': 'OPTION'},
      ],
    });
    expect(hits.single.ticker, 'NSE:RELIANCE');
    final mf = parseSymbolHits('mf', {
      'results': [
        {'symbol': '119551', 'name': 'Fund'},
        {'symbol': 'abc', 'name': 'Bad'},
      ],
    });
    expect(mf.single.ticker, '119551');
  });

  test('LivePrices carries the failed flag and stays a Map', () {
    final p = LivePrices(const {'yahoo:ITC.NS': 1.0}, lookupFailed: true);
    expect(p['yahoo:ITC.NS'], 1.0);
    expect(p.lookupFailed, true);
    expect(const LivePriceResult({}, failed: true).failed, true);
  });
}
