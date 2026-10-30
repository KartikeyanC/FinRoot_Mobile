import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/web_link/presentation/web_link_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:finroot_mobile/features/workspace/presentation/workspace_screen.dart';
import 'package:finroot_mobile/navigation/destinations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Open in browser launches the web app page', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urlOpenerProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TripsScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Trips lives on the web app'), findsOneWidget);
    await tester.tap(find.text('Open in browser'));
    await tester.pump();
    expect(opened.single.path, '/app/trips');
    expect(opened.single.scheme, 'https');
  });

  testWidgets('workspace screen shows the role and the web note', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentMembershipProvider.overrideWithValue(
            const Membership(
              tenantId: 't1',
              name: 'Kumar Household',
              tenantStatus: 'active',
              role: WorkspaceRole.admin,
            ),
          ),
          currentTenantIdProvider.overrideWithValue('t1'),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const WorkspaceScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Kumar Household'), findsOneWidget);
    expect(find.text('Your role: Admin'), findsOneWidget);
    expect(find.textContaining('managed in the web app'), findsOneWidget);
  });

  test('kMoreEntries has unique routes and covers the web sidebar gaps', () {
    final routes = kMoreEntries.map((e) => e.route).toList();
    expect(routes.toSet().length, routes.length);
    expect(
      routes,
      containsAll([
        '/trips',
        '/calculator',
        '/import',
        '/export',
        '/billing',
        '/workspace',
      ]),
    );
  });
}
