import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/budget/application/budget_providers.dart';
import 'package:finroot_mobile/features/budget/domain/budget_spend.dart';
import 'package:finroot_mobile/features/budget/presentation/budget_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<BudgetEntity> budgets = const [],
  List<BudgetSpendRow> spend = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.budget).overrideWithValue(menu),
      budgetsForPeriodProvider.overrideWith((ref) => Stream.value(budgets)),
      budgetSpendRowsProvider.overrideWith((ref) async => spend),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const BudgetScreen()),
  );
}

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('always renders the full 7-jar system, unset buckets included', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    for (final bucket in kBudgetBuckets) {
      expect(find.text(bucket), findsOneWidget);
    }
    // no allocations yet
    expect(find.text('Set a budget'), findsWidgets);
  });

  testWidgets('a bucket with an allocation shows its bar and remaining', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        budgets: [
          BudgetEntity(
            id: 'b1',
            bucket: 'Needs',
            allocated: Money.parse('30000'),
            period: 'monthly',
            periodStart: DateTime.utc(2026, 3),
          ),
        ],
        spend: [
          BudgetSpendRow(
            budgetId: 'b1',
            category: 'Rent',
            total: Money.parse('20000').amount,
            count: 1,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('₹10.0k left'), findsOneWidget);
  });
}
