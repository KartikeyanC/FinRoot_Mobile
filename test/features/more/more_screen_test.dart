import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/more/presentation/more_screen.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:finroot_mobile/navigation/two_pane.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      currentTenantIdProvider.overrideWithValue('t1'),
      currentMembershipProvider.overrideWithValue(
        const Membership(
          tenantId: 't1',
          name: 'Kumar Household',
          tenantStatus: 'active',
          role: WorkspaceRole.owner,
        ),
      ),
      workspaceAccountsProvider.overrideWithValue(
        const AsyncData<List<AccountEntity>>([]),
      ),
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
    ],
    child: MaterialApp(theme: AppTheme.light, home: const MoreScreen()),
  );
}

void main() {
  testWidgets('phone width is a single list under a More app bar', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.byType(TwoPane), findsNothing);
  });

  testWidgets('tablet width shows the list beside the default feature pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byType(TwoPane), findsOneWidget);
    // The default selection is Accounts — its screen (and its own app bar
    // title) is embedded in the detail pane, so "Accounts" shows twice: the
    // list tile and the pane's app bar.
    expect(find.text('Accounts'), findsNWidgets(2));
    expect(find.text('No accounts yet'), findsOneWidget);
  });
}
