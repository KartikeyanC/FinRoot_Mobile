import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/investments/data/live_price_gateway.dart';
import 'package:finroot_mobile/features/investments/data/symbol_search_gateway.dart';
import 'package:finroot_mobile/features/investments/domain/live_price.dart';
import 'package:finroot_mobile/features/investments/domain/symbol_search.dart';
import 'package:finroot_mobile/features/investments/presentation/investment_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Prices implements LivePriceGateway {
  @override
  Future<Map<String, double>> fetch(List<LiveWant> wants) async => const {};
}

class _NoSearch implements SymbolSearchGateway {
  @override
  Future<List<SymbolHit>> search({
    required String asset,
    required String query,
  }) async => const [];
}

Widget _host() => ProviderScope(
  overrides: [
    livePriceGatewayProvider.overrideWithValue(_Prices()),
    symbolSearchGatewayProvider.overrideWithValue(_NoSearch()),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => openInvestmentForm(c),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<void> _openAsBond(WidgetTester tester) async {
  await tester.pumpWidget(_host());
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Stocks'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bonds').last);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
  matching: find.byType(TextFormField),
);

void main() {
  testWidgets('Bonds swaps ticker/quantity for the bond terms', (tester) async {
    await _openAsBond(tester);

    expect(find.textContaining('Ticker'), findsNothing);
    expect(find.textContaining('Quantity'), findsNothing);
    for (final label in [
      'Face value per bond',
      'Number of bonds',
      'Coupon rate (% per year)',
      'Interest payout',
      'Purchase date',
      'Maturity date',
      'Issuer / ISIN (optional)',
      'Credit rating (optional)',
      'Goal link (optional)',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byKey(const ValueKey('bond-summary')), findsOneWidget);
  });

  testWidgets('current value starts at the amount invested, then can be '
      'overridden and reset', (tester) async {
    await _openAsBond(tester);
    final current = find.byKey(const ValueKey('current-value'));

    await tester.enterText(_field('Amount invested').first, '10000');
    await tester.pump();
    // No dates yet, so no interest: the amount invested.
    expect(tester.widget<TextFormField>(current).controller!.text, '10000.00');

    await tester.enterText(current, '12345');
    await tester.pump();
    await tester.enterText(_field('Amount invested').first, '20000');
    await tester.pump();
    expect(tester.widget<TextFormField>(current).controller!.text, '12345');

    await tester.ensureVisible(find.byTooltip('Use the calculated value'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use the calculated value'));
    await tester.pump();
    expect(tester.widget<TextFormField>(current).controller!.text, '20000.00');
  });

  testWidgets('validates amount, coupon rate and dates', (tester) async {
    await _openAsBond(tester);
    await tester.enterText(_field('Name').first, 'NHAI 2031');
    await tester.enterText(_field('Amount invested').first, '0');
    await tester.enterText(find.byKey(const ValueKey('bond-coupon')), '45');
    await tester.tap(find.text('Add holding').last);
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount above 0'), findsOneWidget);
    expect(find.text('Use a rate between 0 and 30%'), findsOneWidget);
    expect(find.text('Pick the purchase date'), findsOneWidget);
    expect(find.text('Pick the maturity date'), findsOneWidget);
  });

  testWidgets('on a small phone the buttons stay on screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _openAsBond(tester);
    final add = find.widgetWithText(FilledButton, 'Add holding');
    final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
    expect(tester.getBottomLeft(add).dy, lessThanOrEqualTo(568));
    expect(tester.getBottomLeft(cancel).dy, lessThanOrEqualTo(568));
    // Tappable without scrolling first.
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bond-summary')), findsNothing);
  });
}
