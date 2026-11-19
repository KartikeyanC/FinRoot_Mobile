import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:finroot_mobile/navigation/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Memberships extends MembershipsNotifier {
  _Memberships(this._list);
  final List<Membership> _list;
  @override
  Future<List<Membership>> build() async => _list;
}

Membership _m(String id, String name) => Membership(
  tenantId: id,
  name: name,
  tenantStatus: 'active',
  role: WorkspaceRole.owner,
);

GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const Text('HOME'))],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/transactions',
              builder: (_, _) => const Text('TXN'),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/trackers', builder: (_, _) => const Text('TRK')),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/more', builder: (_, _) => const Text('MORE')),
          ],
        ),
      ],
    ),
    GoRoute(path: '/settings', builder: (_, _) => const Text('SETTINGS')),
  ],
);

Widget _host({List<Membership> memberships = const []}) {
  return ProviderScope(
    overrides: [
      syncStatusProvider.overrideWithValue(SyncStatusView.empty),
      effectiveMenusProvider.overrideWith((ref) async => const <String>{}),
      membershipsProvider.overrideWith(() => _Memberships(memberships)),
      currentMembershipProvider.overrideWithValue(
        memberships.isEmpty ? null : memberships.first,
      ),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: _router()),
  );
}

void main() {
  testWidgets('phone: More opens a sheet of feature tiles, not a tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add a transaction'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('HOME'), findsOneWidget); // still on the Home tab
    expect(find.text('MORE'), findsNothing);
  });

  testWidgets('phone: the + is docked in the middle of the bottom bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final add = find.byTooltip('Add a transaction');
    expect(add, findsOneWidget);
    // Centred horizontally, and inside the bar rather than floating above it.
    expect(tester.getCenter(add).dx, closeTo(210, 1));
    expect(
      tester.getBottomLeft(add).dy,
      lessThanOrEqualTo(tester.getBottomLeft(find.byKey(kBottomDockKey)).dy),
    );
    expect(
      tester.getTopLeft(add).dy,
      greaterThanOrEqualTo(tester.getTopLeft(find.byKey(kBottomDockKey)).dy),
    );
    // No separate floating action button left to collide with a screen's own.
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('compact width uses the bottom bar, no rail', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byKey(kBottomDockKey), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('expanded width swaps to the rail with a Settings action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(memberships: [_m('t1', 'Kumar Household')]));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(kBottomDockKey), findsNothing);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
  });

  testWidgets('a wide tablet extends the rail and names the workspace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host(memberships: [_m('t1', 'Kumar Household')]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'Settings'), findsOneWidget);
    expect(find.text('Kumar Household'), findsOneWidget);
  });
}
