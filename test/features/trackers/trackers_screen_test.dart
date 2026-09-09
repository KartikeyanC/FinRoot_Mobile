import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/trackers/application/trackers_providers.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:finroot_mobile/features/trackers/presentation/trackers_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TrackerEntity _t(String id, String name, {String? budget}) => TrackerEntity(
  id: id,
  name: name,
  type: 'Travel',
  startDate: DateTime.utc(2026, 3, 2),
  budget: budget == null ? null : Money.parse(budget),
);

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<TrackerWithSpend> trackers = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.trackers).overrideWithValue(menu),
      trackersWithSpendProvider.overrideWithValue(AsyncValue.data(trackers)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const TrackersScreen()),
  );
}

void main() {
  testWidgets('a locked menu shows the paywall state, no FAB', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();

    expect(find.textContaining('isn\'t available'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('lists trackers with a spend bar', (tester) async {
    await tester.pumpWidget(
      _host(
        trackers: foldTrackerSpend(
          [_t('a', 'Dubai Trip', budget: '50000')],
          [
            TrackerSpendRow(
              trackerId: 'a',
              type: 'expense',
              currency: 'INR',
              total: Money.parse('20000').amount,
              count: 3,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('T-Dubai Trip'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('3 transactions'), findsOneWidget);
  });

  testWidgets('empty state offers to create one', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('No trackers here'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create a tracker'), findsOneWidget);
  });
}
