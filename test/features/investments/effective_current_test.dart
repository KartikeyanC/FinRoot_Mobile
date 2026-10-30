import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/domain/live_price.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _rec(
  String asset,
  Map<String, dynamic> extra, {
  String invested = '1000',
  String current = '1200',
}) => InvestmentRecord(
  id: 'x',
  asset: asset,
  currency: 'INR',
  fields: {'invested': invested, 'current': current, '_mobile': '1', ...extra},
  derived: const {},
);

void main() {
  const prices = {'yahoo:ITC.NS': 400.0, 'mf:119551': 50.0};

  test('live price x quantity when priced', () {
    final r = _rec('stocks', {'ticker': 'NSE:ITC', 'quantity': '10'});
    expect(effectiveCurrent(r, prices), 4000);
    expect(effectiveGain(r, prices), 3000);
  });

  test('missing price falls back to stored current', () {
    final r = _rec('stocks', {'ticker': 'NSE:TCS', 'quantity': '10'});
    expect(effectiveCurrent(r, prices), 1200);
  });

  test('zero or missing quantity falls back to stored current', () {
    expect(
      effectiveCurrent(_rec('stocks', {'ticker': 'NSE:ITC'}), prices),
      1200,
    );
    expect(
      effectiveCurrent(
        _rec('stocks', {'ticker': 'NSE:ITC', 'quantity': '0'}),
        prices,
      ),
      1200,
    );
  });

  test('mutual funds use units x NAV', () {
    final r = _rec('mutual_funds', {'scheme': '119551', 'units': '20'});
    expect(effectiveCurrent(r, prices), 1000);
  });

  test('summary uses live values where available, stored otherwise', () {
    final records = [
      _rec('stocks', {'ticker': 'NSE:ITC', 'quantity': '10'}),
      _rec('gold', {}, invested: '500', current: '700'),
    ];
    final live = summarisePortfolio(records, prices);
    expect(live.invested.amount.toDouble(), 1500);
    expect(live.current.amount.toDouble(), 4700);
    expect(live.gain.amount.toDouble(), 3200);
    expect(live.byAsset.first.key, 'stocks');

    final stored = summarisePortfolio(records);
    expect(stored.current.amount.toDouble(), 1900);
  });
}
