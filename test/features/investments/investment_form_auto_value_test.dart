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
  Future<Map<String, double>> fetch(List<LiveWant> wants) async => {
    for (final w in wants) w.key: 400.0,
  };
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

void main() {
  testWidgets('current value switches between manual and automatic', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Manual by default: a Current value input exists.
    expect(find.byKey(const ValueKey('auto-current-value')), findsNothing);
    expect(find.text('Current value'), findsOneWidget);
    final before = find.byType(TextFormField).evaluate().length;

    final fields = find.byType(TextFormField);
    // order: name, ticker, quantity, invested, current
    await tester.enterText(fields.at(1), 'NSE:ITC');
    await tester.pump();
    // Ticker alone is not enough.
    expect(find.byKey(const ValueKey('auto-current-value')), findsNothing);

    await tester.enterText(fields.at(2), '10');
    await tester.pump();
    expect(find.byKey(const ValueKey('auto-current-value')), findsOneWidget);
    expect(find.byType(TextFormField).evaluate().length, before - 1);
    expect(find.textContaining('Calculated once'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('4,000'), findsOneWidget);

    // Clearing the quantity returns to manual entry.
    await tester.enterText(fields.at(2), '');
    await tester.pump();
    expect(find.byKey(const ValueKey('auto-current-value')), findsNothing);
    expect(find.byType(TextFormField).evaluate().length, before);
  });
}
