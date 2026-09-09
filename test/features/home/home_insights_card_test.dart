import 'package:finroot_mobile/design/theme/app_theme.dart';
import 'package:finroot_mobile/features/home/presentation/widgets/home_insights_card.dart';
import 'package:finroot_mobile/features/insights/application/insights_providers.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Insight _i(String id, [String? route]) => Insight(
  id: id,
  kind: InsightKind.neutral,
  title: 'Title $id',
  detail: 'Detail $id',
  route: route,
);

Widget _host(List<Insight> insights) => ProviderScope(
  overrides: [insightsProvider.overrideWithValue(insights)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: HomeInsightsCard()),
  ),
);

void main() {
  testWidgets('hides itself when there are no insights', (t) async {
    await t.pumpWidget(_host(const []));
    await t.pump();
    expect(find.text('Insights'), findsNothing);
  });

  testWidgets('shows the top 3 and an "All N" link when there are more', (t) async {
    await t.pumpWidget(_host([_i('1'), _i('2'), _i('3'), _i('4'), _i('5')]));
    await t.pump();
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.text('Title 3'), findsOneWidget);
    expect(find.text('Title 4'), findsNothing);
    expect(find.text('All 5'), findsOneWidget);
  });

  testWidgets('no "All" link when 3 or fewer', (t) async {
    await t.pumpWidget(_host([_i('1'), _i('2')]));
    await t.pump();
    expect(find.textContaining('All '), findsNothing);
  });
}
