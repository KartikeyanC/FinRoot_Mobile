import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark themes build and carry FinanceColors', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(theme.useMaterial3, isTrue);
      final finance = theme.extension<FinanceColors>();
      expect(finance, isNotNull);
      // Direction colors must be distinct so a row is never ambiguous.
      expect(finance!.income, isNot(finance.expense));
    }
  });

  testWidgets('AmountText renders income positive and expense negative', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Column(
            children: [
              AmountText(18600, type: TxnType.income),
              AmountText(1240, type: TxnType.expense),
            ],
          ),
        ),
      ),
    );

    expect(find.text('₹18,600'), findsOneWidget);
    expect(find.text('-₹1,240'), findsOneWidget);
  });

  testWidgets('TrackerBadge shows the T- display convention', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: TrackerBadge('Home Construction')),
      ),
    );
    expect(find.text('T-Home Construction'), findsOneWidget);
  });
}
