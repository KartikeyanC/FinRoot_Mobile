import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/presentation/investments_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/price_alerts/application/price_alerts_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _rec(
  String name,
  String invested,
  String current, {
  String asset = 'stocks',
}) =>
    InvestmentRecord(
      id: name,
      asset: asset,
      currency: 'INR',
      fields: {
        'name': name,
        'invested': invested,
        'current': current,
        '_mobile': '1',
      },
      derived: const {},
    );

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<InvestmentRecord> records = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.investments).overrideWithValue(menu),
      investmentsProvider.overrideWith((ref) async => records),
      holdingPricesProvider.overrideWith((ref) async => const {}),
      priceAlertsProvider.overrideWith((ref) async => const []),
      alertPricesProvider.overrideWith((ref) async => const {}),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const InvestmentsScreen()),
  );
}

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('empty state offers to add', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('No holdings yet'), findsOneWidget);
  });

  testWidgets('lists holdings with a portfolio summary', (tester) async {
    await tester.pumpWidget(
      _host(
        records: [
          _rec('ITC', '10000', '13000'),
          _rec('Gold ETF', '20000', '19000'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('ITC'), findsOneWidget);
    expect(find.text('Invested'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('30,000.00'), findsOneWidget);
    expect(find.text('32,000.00'), findsOneWidget);
    // total gain 3000 - 1000 = +2000 on 30000 invested → +6.67%
    expect(
      tester.widget<Text>(find.byKey(const Key('summary-pnl'))).data,
      '+2,000.00',
    );
    expect(find.text('+6.67%'), findsOneWidget);
    expect(find.text('Holdings · 2'), findsOneWidget);
  });

  testWidgets('a holding card reads qty/avg | %, name | profit, '
      'invested | total', (tester) async {
    await tester.pumpWidget(
      _host(
        records: [
          const InvestmentRecord(
            id: 'itc',
            asset: 'stocks',
            currency: 'INR',
            fields: {
              'name': 'ITC',
              'qty': '10',
              'buy': '200',
              'invested': '2000',
              'current': '2500',
              '_mobile': '1',
            },
            derived: {},
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Qty. 10  •  Avg. 200.00'), findsOneWidget);
    expect(find.byKey(const Key('holding-pct')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('holding-pct'))).data,
      '+25.00%',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('holding-gain'))).data,
      '+500.00',
    );
    // Shown as "Invt.", read aloud as "Invested".
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.textSpan?.toPlainText(includeSemanticsLabels: false) ==
                'Invt. 2,000.00',
      ),
      findsOneWidget,
    );
    expect(find.text('Invested 2,000.00', findRichText: true), findsOneWidget);
    expect(find.text('Total 2,500.00', findRichText: true), findsOneWidget);

    // Tapping the row opens its detail sheet with Edit and Delete.
    await tester.tap(find.text('ITC'));
    await tester.pumpAndSettle();
    expect(find.text('Edit holding'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('P&L'), findsWidgets);
  });

  testWidgets('price alerts are a tab of Investments', (tester) async {
    await tester.pumpWidget(_host(records: [_rec('ITC', '100', '120')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Holdings · 1'), findsOneWidget);
    await tester.tap(find.text('Price alerts'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('No price alerts yet'), findsOneWidget);
  });

  testWidgets('stocks and mutual funds are split by type', (tester) async {
    await tester.pumpWidget(
      _host(
        records: [
          _rec('ITC', '1000', '1200'),
          _rec('Parag Parikh Flexi Cap', '5000', '5500', asset: 'mutual_funds'),
          _rec('HDFC Bank', '2000', '1900'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // All: every row, under a header per type, stocks first.
    expect(find.byKey(const Key('asset-tab-all')), findsOneWidget);
    expect(find.text('Stocks  ·  2'), findsOneWidget);
    expect(find.text('Mutual Funds  ·  1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('type-header-stocks'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('type-header-mutual_funds'))).dy,
      ),
    );
    expect(find.text('8,000.00'), findsOneWidget); // invested, everything

    // Mutual Funds: only the fund, and the card totals only the fund.
    await tester.tap(find.byKey(const Key('asset-tab-mutual_funds')));
    await tester.pump();
    expect(find.text('Parag Parikh Flexi Cap'), findsOneWidget);
    expect(find.text('ITC'), findsNothing);
    expect(find.text('HDFC Bank'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('summary-pnl'))).data,
      '+500.00',
    );
    expect(find.byKey(const Key('type-header-stocks')), findsNothing);

    // Stocks: the two stocks.
    await tester.tap(find.byKey(const Key('asset-tab-stocks')));
    await tester.pump();
    expect(find.text('ITC'), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('Parag Parikh Flexi Cap'), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('summary-pnl'))).data,
      '+100.00',
    );
  });

  testWidgets('one type only: no type tabs', (tester) async {
    await tester.pumpWidget(_host(records: [_rec('ITC', '100', '120')]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byKey(const Key('asset-tab-all')), findsNothing);
  });
}
