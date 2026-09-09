import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/goals/domain/goal.dart';
import 'package:finroot_mobile/features/goals/presentation/goals_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

GoalEntity _goal(
  String id,
  String title, {
  String target = '10000',
  String current = '0',
  String status = 'active',
}) => GoalEntity(
  id: id,
  title: title,
  target: Money.parse(target),
  current: Money.parse(current),
  status: status,
);

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<GoalEntity> goals = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.goals).overrideWithValue(menu),
      goalsProvider.overrideWith((ref) => Stream.value(goals)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const GoalsScreen()),
  );
}

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('empty state offers to add a goal', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('No goals yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add a goal'), findsOneWidget);
  });

  testWidgets('lists goals with progress and an Add funds action', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        goals: [
          _goal('a', 'Emergency fund', target: '100000', current: '40000'),
          _goal('b', 'New phone', target: '50000', current: '50000',
              status: 'completed'),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Emergency fund'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('Add funds'), findsOneWidget); // only the active one
    expect(find.text('New phone'), findsOneWidget);
    expect(find.text('Reached'), findsOneWidget);
  });
}
