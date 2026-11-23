import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/home/application/home_layout_controller.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/home/domain/home_layout.dart';
import 'package:finroot_mobile/features/home/presentation/home_layout_screen.dart';
import 'package:finroot_mobile/features/home/presentation/home_screen.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/trackers/application/trackers_providers.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'finroot.home.layout';

/// Home and "Customize home" under a real router, with device prefs seeded
/// from [stored] (an encoded [HomeLayout]).
Future<SharedPreferences> _pump(
  WidgetTester tester, {
  HomeLayout? stored,
  String start = '/',
  Set<FeatureMenu> locked = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    if (stored != null) _key: stored.encode(),
  });
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: HomeLayoutScreen.route,
        builder: (_, _) => const HomeLayoutScreen(),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        for (final m in FeatureMenu.values)
          menuStatusProvider(m).overrideWithValue(
            locked.contains(m) ? MenuStatus.locked : MenuStatus.available,
          ),
        workspaceSummaryProvider.overrideWithValue(
          AsyncValue.data(WorkspaceSummary.empty()),
        ),
        debtsProvider.overrideWith((ref) async => const <Debt>[]),
        investmentsProvider.overrideWith((ref) async => const []),
        goalsProvider.overrideWith((ref) => Stream.value(const [])),
        recurringItemsProvider.overrideWith(
          (ref) async => const <RecurringItem>[],
        ),
        currentUserProvider.overrideWithValue(null),
        profileProvider.overrideWith(
          (ref) async => const Profile(id: 'u1', displayName: 'Priya Kumar'),
        ),
        currentMembershipProvider.overrideWithValue(
          const Membership(
            tenantId: 't1',
            name: 'Kumar Household',
            tenantStatus: 'active',
            role: WorkspaceRole.owner,
          ),
        ),
        syncStatusProvider.overrideWithValue(SyncStatusView.empty),
        recentTransactionsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        recentActivityCountProvider.overrideWith((ref) => Stream.value(0)),
        trackersWithSpendProvider.overrideWithValue(
          AsyncValue.data(foldTrackerSpend(const [], null)),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  return prefs;
}

HomeLayout _layoutOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(Scaffold).first),
).read(homeLayoutProvider);

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  // Tall phone, so every card on Home is built.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 12000);
    view.devicePixelRatio = 2.625;
  });
  tearDown(
    () => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .reset(),
  );

  testWidgets('Home follows the saved order and leaves hidden cards out', (
    tester,
  ) async {
    await _pump(
      tester,
      stored: HomeLayout.defaults
          .move(HomeBlock.bills.index, 0)
          .withShown(HomeBlock.cashFlow, false),
    );

    expect(find.text('Upcoming bills'), findsOneWidget);
    expect(find.text('NET WORTH'), findsOneWidget);
    expect(_top(tester, 'Upcoming bills'), lessThan(_top(tester, 'NET WORTH')));
    expect(find.text('Cash flow'), findsNothing);
    expect(find.text('Customize home'), findsOneWidget);
  });

  testWidgets('the spending chart can come first', (tester) async {
    await _pump(
      tester,
      stored: HomeLayout.defaults.move(HomeBlock.spending.index, 0),
    );

    expect(_top(tester, 'Net spending'), lessThan(_top(tester, 'NET WORTH')));
  });

  testWidgets('with every card off, Home offers the way back', (tester) async {
    var all = HomeLayout.defaults;
    for (final b in HomeBlock.values) {
      all = all.withShown(b, false);
    }
    await _pump(tester, stored: all);

    expect(find.text('All Home cards are off'), findsOneWidget);
    await tester.tap(find.text('Customize home'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeLayoutScreen), findsOneWidget);
  });

  testWidgets('long-pressing a card opens Customize home', (tester) async {
    await _pump(tester);

    await tester.longPress(find.text('Financial health'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeLayoutScreen), findsOneWidget);
  });

  testWidgets('turning a card off saves it and takes it off Home', (
    tester,
  ) async {
    final prefs = await _pump(tester);
    await tester.tap(find.text('Customize home'));
    await tester.pumpAndSettle();

    // Every card is listed, each with its own switch.
    expect(find.byType(Switch), findsNWidgets(HomeBlock.values.length));
    final cashFlowRow = find.ancestor(
      of: find.text('Cash flow'),
      matching: find.byType(MergeSemantics),
    );
    await tester.tap(
      find.descendant(of: cashFlowRow, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(_layoutOf(tester).isShown(HomeBlock.cashFlow), isFalse);
    expect(
      HomeLayout.decode(prefs.getString(_key)).isShown(HomeBlock.cashFlow),
      isFalse,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Cash flow'), findsNothing);
    expect(find.text('Financial health'), findsOneWidget);
  });

  testWidgets('dragging a card by its handle moves it and saves the order', (
    tester,
  ) async {
    final prefs = await _pump(tester, start: HomeLayoutScreen.route);

    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final rowHeight = tester
        .getSize(
          find
              .ancestor(of: handle, matching: find.byType(AppCard))
              .first,
        )
        .height;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(0, rowHeight / 2));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final order = _layoutOf(tester).order;
    expect(order.indexOf(HomeBlock.nudge), greaterThan(0));
    expect(order.toSet(), HomeBlock.values.toSet());
    expect(HomeLayout.decode(prefs.getString(_key)).order, order);
  });

  testWidgets('reset puts the default back, and Undo restores the layout', (
    tester,
  ) async {
    final custom = HomeLayout.defaults
        .move(HomeBlock.investments.index, 0)
        .withShown(HomeBlock.health, false);
    final prefs = await _pump(
      tester,
      stored: custom,
      start: HomeLayoutScreen.route,
    );

    await tester.tap(find.byTooltip('Reset to default'));
    await tester.pumpAndSettle();
    expect(_layoutOf(tester).isDefault, isTrue);
    expect(prefs.getString(_key), isNull);
    expect(find.text('Home is back to the default layout'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_layoutOf(tester), custom);
    expect(HomeLayout.decode(prefs.getString(_key)), custom);
  });

  testWidgets('a card the plan locks says so, and stays off Home', (
    tester,
  ) async {
    await _pump(tester, locked: {FeatureMenu.reminders});
    expect(find.text('Upcoming bills'), findsNothing);

    await tester.tap(find.text('Customize home'));
    await tester.pumpAndSettle();
    final billsRow = find.ancestor(
      of: find.text('Upcoming bills'),
      matching: find.byType(MergeSemantics),
    );
    expect(
      find.descendant(of: billsRow, matching: find.text('Not on your plan')),
      findsOneWidget,
    );
  });

  testWidgets('reset is off while Home is already the default', (
    tester,
  ) async {
    await _pump(tester, start: HomeLayoutScreen.route);

    final button = tester.widget<RoundIconButton>(
      find.ancestor(
        of: find.byIcon(Icons.restart_alt_rounded),
        matching: find.byType(RoundIconButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
