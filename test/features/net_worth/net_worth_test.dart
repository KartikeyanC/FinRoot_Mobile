import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/net_worth/domain/net_worth.dart';
import 'package:flutter_test/flutter_test.dart';

NetWorthEntry _e(String kind, String amount) => NetWorthEntry(
  id: kind + amount,
  kind: kind,
  group: kind == 'asset' ? 'bank' : 'home_loan',
  name: 'x',
  amount: Money.parse(amount),
);

void main() {
  test('totals: net worth = assets - liabilities', () {
    final t = NetWorthTotals.of([
      _e('asset', '500000'),
      _e('asset', '250000'),
      _e('liability', '300000'),
    ]);
    expect(t.assets.amount, Decimal.parse('750000'));
    expect(t.liabilities.amount, Decimal.parse('300000'));
    expect(t.netWorth.amount, Decimal.parse('450000'));
  });

  test('net worth can be negative', () {
    final t = NetWorthTotals.of([_e('liability', '100000')]);
    expect(t.netWorth.amount, Decimal.parse('-100000'));
  });

  test('NetWorthEntry.fromRow maps grp → group and amount → Money', () {
    final e = NetWorthEntry.fromRow({
      'id': 'r1',
      'kind': 'asset',
      'grp': 'stocks',
      'name': 'Zerodha',
      'amount': 123456,
      'created_at': '2026-09-01T00:00:00Z',
    });
    expect(e.group, 'stocks');
    expect(e.amount.amount, Decimal.parse('123456'));
    expect(e.isAsset, isTrue);
  });

  test('NetWorthPoint computes net worth from a snapshot row', () {
    final p = NetWorthPoint.fromRow({
      'captured_on': '2026-09-01',
      'assets': '800000',
      'liabilities': '300000',
      'net_worth': '500000',
    });
    expect(p.netWorth.amount, Decimal.parse('500000'));
  });

  test('groupLabel resolves asset and liability groups, falls back', () {
    expect(groupLabel('home_loan'), 'Home EMI');
    expect(groupLabel('mutual_funds'), 'Mutual Funds');
    expect(groupLabel('mystery'), 'mystery');
  });

  group('NetWorthValidators', () {
    test('name required, amount must be positive', () {
      expect(NetWorthValidators.name(''), isNotNull);
      expect(NetWorthValidators.name('Flat'), isNull);
      expect(NetWorthValidators.amount('0'), isNotNull);
      expect(NetWorthValidators.amount('-5'), isNotNull);
      expect(NetWorthValidators.amount('250000'), isNull);
    });
  });
}
