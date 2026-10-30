import 'dart:async';

import 'package:finroot_mobile/app/router.dart';
import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/insights/application/insights_providers.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/trackers/application/trackers_providers.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:finroot_mobile/navigation/destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

/// "Every button works": drives the REAL router + app shell with the data
/// layer stubbed, and taps through the primary navigation, the More entries
/// and the add-sheets. No network.

class _Memberships extends MembershipsNotifier {
  @override
  Future<List<Membership>> build() async => const [_membership];
}

const _membership = Membership(
  tenantId: 't1',
  name: 'Kumar Household',
  tenantStatus: 'active',
  role: WorkspaceRole.owner,
);

List<Override> _overrides(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  isSignedInProvider.overrideWithValue(true),
  authEventProvider.overrideWith((ref) => const Stream<AuthState>.empty()),
  membershipsProvider.overrideWith(_Memberships.new),
  currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
  currentTenantIdProvider.overrideWithValue('t1'),
  currentUserProvider.overrideWithValue(null),
  currentUserIdProvider.overrideWithValue('u1'),
  currentMembershipProvider.overrideWithValue(_membership),
  syncStatusProvider.overrideWithValue(SyncStatusView.empty),
  profileProvider.overrideWith(
    (ref) async => const Profile(id: 'u1', displayName: 'Tester'),
  ),
  recentTransactionsProvider.overrideWith((ref) => Stream.value(const [])),
  recentActivityCountProvider.overrideWith((ref) => Stream.value(0)),
  ledgerProvider.overrideWith((ref) => Stream.value(const [])),
  effectiveMenusProvider.overrideWith(
    (ref) async => {for (final m in FeatureMenu.values) m.id},
  ),
  homeInsightsProvider.overrideWithValue(const <Insight>[]),
  insightsProvider.overrideWithValue(const <Insight>[]),
  recurringItemsProvider.overrideWith((ref) async => const <RecurringItem>[]),
  remindersProvider.overrideWith((ref) async => const <Reminder>[]),
  trackersWithSpendProvider.overrideWithValue(
    const AsyncValue.data(<TrackerWithSpend>[]),
  ),
  trackerSpendRowsProvider.overrideWith(
    (ref) async => const <TrackerSpendRow>[],
  ),
  workspaceAccountsProvider.overrideWith((ref) => Stream.value(const [])),
  workspaceSummaryProvider.overrideWithValue(
    AsyncValue.data(
      WorkspaceSummary(
        accountDeltas: const [],
        monthIncome: Money.zero(),
        monthExpense: Money.zero(),
        transactionCount: 0,
        fetchedAt: DateTime(2026, 9, 9),
        
        
        
      ),
    ),
  ),
  debtsProvider.overrideWith((ref) async => const <Debt>[]),
  investmentsProvider.overrideWith((ref) async => const []),
  goalsProvider.overrideWith((ref) => Stream.value(const [])),
];

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  late GoRouter router;
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(prefs),
      child: Consumer(
        builder: (context, ref, _) {
          router = ref.watch(routerProvider);
          return MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await _settle(tester);
  return router;
}

/// Screens may keep a looping animation (spinners); settle a bounded time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

String _loc(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

/// Like [testWidgets], but unmounts the app and flushes the zero-length timers
/// drift's stream cache schedules when the provider scope is disposed.
void _test(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  });
}

void main() {
  _test('bottom bar tabs switch screens', (tester) async {
    final router = await _pumpApp(tester);
    expect(_loc(router), '/');
    for (final d in [
      AppDestination.transactions,
      AppDestination.trackers,
      AppDestination.home,
    ]) {
      await tester.tap(find.bySemanticsLabel(d.label).first);
      await _settle(tester);
      expect(_loc(router), d.path, reason: d.label);
      expect(tester.takeException(), isNull);
    }
  });

  _test('the + button opens Quick Add; empty amount is rejected', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byTooltip('Add a transaction'));
    await _settle(tester);
    expect(find.widgetWithText(FilledButton, 'Save expense'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save expense'));
    await tester.pump();
    // Still open: the sheet was not dismissed by an invalid submit.
    expect(find.widgetWithText(FilledButton, 'Save expense'), findsOneWidget);
    // Cancel closes it.
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.widgetWithText(FilledButton, 'Save expense'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _test('More sheet: every entry opens its own screen', (tester) async {
    final router = await _pumpApp(tester);
    for (final e in kMoreEntries) {
      await tester.tap(find.bySemanticsLabel('More'));
      await _settle(tester);
      final tile = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(e.label),
      );
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await _settle(tester);
      expect(_loc(router), e.route, reason: e.label);
      expect(find.byType(PlaceholderScreen), findsNothing, reason: e.label);
      expect(tester.takeException(), isNull, reason: e.label);
      router.pop();
      await _settle(tester);
    }
  });

  _test('every More route resolves to a real screen', (tester) async {
    final router = await _pumpApp(tester);
    for (final e in kMoreEntries) {
      unawaited(router.push(e.route));
      await _settle(tester);
      expect(_loc(router), e.route, reason: e.label);
      expect(find.byType(PlaceholderScreen), findsNothing, reason: e.label);
      expect(tester.takeException(), isNull, reason: e.label);
      router.pop();
      await _settle(tester);
    }
  });

  _test('Add a holding opens its sheet; empty submit is blocked', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.push('/investments'));
    await _settle(tester);
    await tester.tap(find.text('Add a holding'));
    await _settle(tester);
    expect(find.text('Add holding'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Add holding'));
    await _settle(tester);
    // Validation failed, sheet still showing.
    expect(find.widgetWithText(FilledButton, 'Add holding'), findsOneWidget);
    // Dismiss by tapping the scrim.
    await Navigator.of(tester.element(find.byType(FilledButton).last)).maybePop();
    await _settle(tester);
    expect(find.widgetWithText(FilledButton, 'Add holding'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _test('Add a goal opens its sheet; empty submit is blocked', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.push('/goals'));
    await _settle(tester);
    await tester.tap(find.text('Add a goal'));
    await _settle(tester);
    expect(find.text('New goal'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add goal'));
    await _settle(tester);
    expect(find.text('New goal'), findsOneWidget);
    await Navigator.of(tester.element(find.byType(FilledButton).last)).maybePop();
    await _settle(tester);
    expect(find.text('New goal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  _test('Add reminder opens its sheet and Cancel closes it', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    unawaited(router.push('/reminders'));
    await _settle(tester);
    await tester.tap(find.text('Add reminder'));
    await _settle(tester);
    expect(find.text('Schedule'), findsOneWidget);
    await tester.tap(find.text('Schedule'));
    await _settle(tester);
    expect(find.text('Schedule'), findsOneWidget); // blocked: no title
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(find.text('Schedule'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
