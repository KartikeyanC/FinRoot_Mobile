import 'package:finroot_mobile/features/investments/domain/holding_figures.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/domain/stock_lots.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _buy(String id, String qty, String buy, String date) =>
    InvestmentRecord(
      id: id,
      asset: 'stocks',
      currency: 'INR',
      fields: {
        'name': 'ITC',
        'ticker': 'ITC.NS',
        'qty': qty,
        'buy': buy,
        'buy_date': date,
        'invested': '${double.parse(qty) * double.parse(buy)}',
        'current': '${double.parse(qty) * double.parse(buy)}',
        '_mobile': '1',
      },
      derived: const {},
    );

void main() {
  group('amount formats', () {
    test('rupees: two decimals, Indian grouping, no symbol', () {
      expect(plainAmount(142929.31, 'INR'), '1,42,929.31');
      expect(plainAmount(410, 'INR'), '410.00');
    });

    test('other currencies keep their symbol', () {
      expect(plainAmount(1204.5, 'USD'), r'$1,204.50');
    });

    test('signed amount and percent', () {
      expect(signedAmount(212.32, 'INR'), '+212.32');
      expect(signedAmount(-1811.86, 'INR'), '-1,811.86');
      expect(signedPct(137.889), '+137.89%');
      expect(signedPct(-2.45), '-2.45%');
      expect(signedPct(null), '—');
    });
  });

  group('figuresFor', () {
    test('a single holding: total is invested + profit at the live price', () {
      final r = _buy('a', '10', '410', '2026-10-28');
      final h = figuresFor(SingleHolding(r), const {'yahoo:ITC.NS': 438.0});
      expect(h.qty, 10);
      expect(h.avgPrice, 410);
      expect(h.livePrice, 438);
      expect(h.invested, 4100);
      expect(h.current, closeTo(4380, 1e-9));
      expect(h.gain, closeTo(280, 1e-9));
      expect(h.returnPct, closeTo(6.829, 1e-3));
      expect(h.isGroup, isFalse);
    });

    test('a stock bought twice: weighted average, one row', () {
      final items = groupPortfolio([
        _buy('a', '2', '200', '2026-10-28'),
        _buy('b', '2', '220', '2026-10-29'),
      ]);
      final h = figuresFor(items.single, const {'yahoo:ITC.NS': 265.0});
      expect(h.isGroup, isTrue);
      expect(h.qty, 4);
      expect(h.avgPrice, 210);
      expect(h.current, 1060);
      expect(h.gain, 220);
    });

    test('without a live price it falls back to the stored value', () {
      final h = figuresFor(
        SingleHolding(_buy('a', '10', '410', '2026-10-28')),
        const {},
      );
      expect(h.livePrice, isNull);
      expect(h.current, 4100);
      expect(h.returnPct, 0);
    });
  });

  group('splitting by type', () {
    InvestmentRecord rec(String id, String asset) => InvestmentRecord(
      id: id,
      asset: asset,
      currency: 'INR',
      fields: {'name': id, 'invested': '100', 'current': '110', '_mobile': '1'},
      derived: const {},
    );

    test('types come in the usual order, each with its row count', () {
      final items = groupPortfolio([
        rec('gold', 'gold'),
        rec('fund1', 'mutual_funds'),
        rec('infy', 'stocks'),
        rec('fund2', 'mutual_funds'),
        rec('odd', 'something_new'),
      ]);
      expect(
        [for (final t in assetBreakdown(items)) '${t.asset}:${t.count}'],
        ['stocks:1', 'mutual_funds:2', 'gold:1', 'something_new:1'],
      );
    });

    test('a stock bought twice counts as one row of its type', () {
      final items = groupPortfolio([
        _buy('a', '2', '200', '2026-10-28'),
        _buy('b', '2', '220', '2026-10-29'),
      ]);
      expect(assetBreakdown(items).single, (asset: 'stocks', count: 1));
      expect(recordsOf(items.single), hasLength(2));
    });
  });
}
