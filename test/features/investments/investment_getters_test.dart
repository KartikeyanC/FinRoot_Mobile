import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:flutter_test/flutter_test.dart';

/// The invested / current getters mirror the FinRoot **web** repo's
/// `src/lib/investmentsStore.ts` per-asset logic, plus a `_mobile` fast path
/// for records this app writes.

InvestmentRecord _rec(
  String asset, {
  Map<String, dynamic> fields = const {},
  Map<String, dynamic> derived = const {},
}) => InvestmentRecord(
  id: 'i',
  asset: asset,
  currency: 'INR',
  fields: fields,
  derived: derived,
);

void main() {
  test('a mobile record reads fields.invested / fields.current directly', () {
    final r = _rec(
      'stocks',
      fields: {'name': 'ITC', 'invested': '10000', 'current': '13500', '_mobile': '1'},
    );
    expect(r.invested.amount, Decimal.parse('10000'));
    expect(r.current.amount, Decimal.parse('13500'));
    expect(r.gain.amount, Decimal.parse('3500'));
    expect(r.name, 'ITC');
  });

  group('web records — per-asset keys', () {
    test('stocks: invested = derived.total, current = fields.current || derived.total', () {
      final r = _rec('stocks', fields: {'current': '9000'}, derived: {'total': '8000'});
      expect(r.invested.amount, Decimal.parse('8000'));
      expect(r.current.amount, Decimal.parse('9000'));
    });

    test('mutual_funds: invested = fields.invested, current = derived.currentValue', () {
      final r = _rec('mutual_funds',
          fields: {'invested': '50000'}, derived: {'currentValue': '61000'});
      expect(r.invested.amount, Decimal.parse('50000'));
      expect(r.current.amount, Decimal.parse('61000'));
    });

    test('fd: deposit / maturity', () {
      final r = _rec('fd', fields: {'deposit': '100000'}, derived: {'maturity': '107000'});
      expect(r.invested.amount, Decimal.parse('100000'));
      expect(r.current.amount, Decimal.parse('107000'));
    });

    test('pf: contribTotal wins over balance; total wins over balance', () {
      final r = _rec('pf',
          fields: {'balance': '200000'},
          derived: {'contribTotal': '180000', 'total': '210000'});
      expect(r.invested.amount, Decimal.parse('180000'));
      expect(r.current.amount, Decimal.parse('210000'));
    });

    test('current falls back to invested when no current figure exists', () {
      final r = _rec('mutual_funds', fields: {'invested': '5000'});
      expect(r.current.amount, Decimal.parse('5000'));
    });

    test('name falls back through ticker / scheme / asset label', () {
      expect(_rec('stocks', fields: {'ticker': 'RELIANCE'}).name, 'RELIANCE');
      expect(_rec('mutual_funds', fields: {'scheme': 'Nifty 50'}).name, 'Nifty 50');
      expect(_rec('gold').name, 'Gold');
    });
  });

  test('assetLabel / assetIcon tolerate an unknown asset', () {
    expect(assetLabel('mystery'), 'mystery');
    expect(assetIcon('mystery'), isNotNull);
  });
}
