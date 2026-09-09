import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/theme/app_theme.dart';
import 'package:finroot_mobile/features/insights/application/insights_providers.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:finroot_mobile/features/insights/presentation/insights_screen.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({List<Insight>? insights}) => ProviderScope(
  overrides: [
    workspaceSummaryProvider.overrideWith((ref) async => WorkspaceSummary(
      accountDeltas: const [],
      monthIncome: Money(Decimal.zero),
      monthExpense: Money(Decimal.zero),
      transactionCount: 0,
      fetchedAt: DateTime(2026, 9, 15),
    )),
    if (insights != null) insightsProvider.overrideWithValue(insights),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const InsightsScreen()),
);

void main() {
  testWidgets('shows the onboarding line when the engine is empty', (t) async {
    await t.pumpWidget(_host());
    await t.pumpAndSettle();
    expect(find.textContaining('Insights build as you log'), findsOneWidget);
  });

  testWidgets('renders each insight with its detail', (t) async {
    await t.pumpWidget(_host(insights: const [
      Insight(
        id: 'a',
        kind: InsightKind.watch,
        title: 'Spending is up 30% vs last month',
        detail: 'was 40k, now 52k',
        route: '/budget',
      ),
      Insight(
        id: 'b',
        kind: InsightKind.positive,
        title: "You've saved 35% of your income",
        detail: 'nice',
      ),
    ]));
    await t.pumpAndSettle();
    expect(find.text('Spending is up 30% vs last month'), findsOneWidget);
    expect(find.text("You've saved 35% of your income"), findsOneWidget);
  });
}
