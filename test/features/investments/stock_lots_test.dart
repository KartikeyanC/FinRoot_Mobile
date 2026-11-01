import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/domain/stock_lots.dart';
import 'package:finroot_mobile/features/investments/presentation/investments_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/price_alerts/application/price_alerts_providers.dart';
import 'package:finroot_mobile/features/price_alerts/domain/price_alert.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A purchase as the web writes it (Add Investment, Direct Stocks).
InvestmentRecord _buy(String id, String ticker, String buy, String qty, String date) =>
    InvestmentRecord(
      id: id,
      asset: 'stocks',
      currency: 'INR',
      fields: {'name': 'ITC', 'ticker': ticker, 'buy': buy, 'qty': qty, 'buy_date': date},
      derived: {'total': double.parse(buy) * double.parse(qty)},
      savedAt: DateTime.utc(2026, 10),
    );

// The user's example: 200 x 2 today, 220 x 2 tomorrow.
final _day1 = _buy('a', 'ITC.NS', '200', '2', '2026-10-28');
final _day2 = _buy('b', 'NSE:ITC', '220', '2', '2026-10-29');

void main() {
  group('the rules match the web (src/lib/stockLots.ts)', () {
    test('NSE:ITC and ITC.NS are the same stock; other assets never merge', () {
      expect(lotKey(_day1), 'ITC.NS|INR');
      expect(lotKey(_day2), 'ITC.NS|INR');
      const fd = InvestmentRecord(id: 'f', asset: 'fd', currency: 'INR', fields: {}, derived: {});
      expect(lotKey(fd), isNull);
    });

    test('two buys become one holding with the weighted average', () {
      final items = groupPortfolio([_day2, _day1]);
      expect(items, hasLength(1));
      final g = (items.single as GroupedHolding).group;
      expect(g.name, 'ITC');
      expect(g.qty, 4);
      expect(g.invested, 840);
      expect(g.avgPrice, 210);
      expect(g.lots.map((l) => l.record.id), ['a', 'b']);
      expect(g.lots.first.price, 200);
    });

    test('a stock bought once stays a single row, in place', () {
      final infy = _buy('i', 'INFY.NS', '1500', '1', '2026-10-20');
      final items = groupPortfolio([infy, _day1, _day2]);
      expect(items.first, isA<SingleHolding>());
      expect(items.last, isA<GroupedHolding>());
    });

    test('holdings added on the phone (amounts only) merge by name', () {
      InvestmentRecord mobile(String id, String inv) => InvestmentRecord(
        id: id,
        asset: 'stocks',
        currency: 'INR',
        fields: {'name': 'itc', 'invested': inv, 'current': inv, '_mobile': '1'},
        derived: const {},
      );
      final g = (groupPortfolio([mobile('m1', '400'), mobile('m2', '440')]).single as GroupedHolding).group;
      expect(g.invested, 840);
      expect(g.qty, 0);
      expect(g.avgPrice, 0, reason: 'no quantity recorded, so no average to show');
    });

    test('current value uses each purchase\'s live value when priced', () {
      final g = (groupPortfolio([_day1, _day2]).single as GroupedHolding).group;
      expect(groupCurrent(g, {'yahoo:ITC.NS': 265}), 1060);
      expect(groupCurrent(g, const {}), 840);
    });
  });

  testWidgets('the Investments list shows ITC once and opens to each purchase', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          menuStatusProvider(FeatureMenu.investments).overrideWithValue(MenuStatus.available),
          investmentsProvider.overrideWith((ref) async => [_day2, _day1]),
          holdingPricesProvider.overrideWith((ref) async => {'yahoo:ITC.NS': 265.0}),
          alertPricesProvider.overrideWith((ref) async => {'yahoo:ITC.NS': 265.0}),
          priceAlertsProvider.overrideWith(
            (ref) async => [
              PriceAlert(
                id: 'x',
                symbol: 'ITC.NS',
                name: 'ITC',
                target: 250,
                direction: AlertDirection.below,
                createdAt: DateTime.utc(2026, 10, 28),
              ),
            ],
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const InvestmentsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('ITC'), findsOneWidget);
    expect(find.text('Qty. 4  •  Avg. 210.00  •  2 buys'), findsOneWidget);
    // The alarm tag after Invested: just the alarm and the amount.
    expect(find.text('250.00'), findsOneWidget);
    // 4 shares at 265 live = 1,060 on 840 invested.
    expect(find.text('Total 1,060.00', findRichText: true), findsOneWidget);
    expect(find.text('28 Oct 2026'), findsNothing);

    // The row opens its sheet: LTP, the alert and each purchase.
    await tester.tap(find.text('ITC'));
    await tester.pumpAndSettle();
    expect(find.text('265.00'), findsOneWidget);
    expect(find.text('Falls to 250.00'), findsOneWidget);
    expect(find.text('28 Oct 2026'), findsOneWidget);
    expect(find.text('29 Oct 2026'), findsOneWidget);
    Navigator.of(tester.element(find.text('28 Oct 2026'))).pop();
    await tester.pumpAndSettle();

    // The alarm tag opens this stock's alerts, in place.
    await tester.tap(find.byKey(const Key('holding-alarm')));
    await tester.pumpAndSettle();
    expect(find.text('Price alerts · ITC'), findsOneWidget);
    expect(find.text('Add another alert'), findsOneWidget);
  });
}
