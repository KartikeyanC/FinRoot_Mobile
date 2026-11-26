import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/billing/data/billing_gateway.dart';
import 'package:finroot_mobile/features/billing/domain/billing.dart';
import 'package:finroot_mobile/features/billing/presentation/billing_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/web_link/presentation/web_link_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'billing_fakes.dart';

Widget _host(
  FakeBillingGateway gateway, {
  WorkspaceRole role = WorkspaceRole.owner,
  bool online = true,
  List<Uri>? opened,
  Set<String>? menus,
}) => ProviderScope(
  overrides: [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(role),
    currentMembershipProvider.overrideWithValue(
      Membership(
        tenantId: 't1',
        name: 'Kumar Household',
        tenantStatus: 'active',
        role: role,
      ),
    ),
    isOnlineProvider.overrideWithValue(online),
    effectiveMenusProvider.overrideWith(
      (ref) async => menus ?? {for (final m in FeatureMenu.values) m.id},
    ),
    billingGatewayProvider.overrideWithValue(gateway),
    urlOpenerProvider.overrideWithValue((uri) async {
      opened?.add(uri);
      return true;
    }),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const BillingScreen()),
);

Future<void> _pump(WidgetTester tester, Widget host) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the current plan with the web\'s facts', (tester) async {
    final gateway = FakeBillingGateway(overviewJson: activeCanopy());
    await _pump(tester, _host(gateway));

    expect(gateway.overviewCalls, ['t1']);
    expect(find.text('Billing & plans'), findsOneWidget);
    expect(find.text('Canopy'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('₹299.00 / month'), findsOneWidget);
    expect(find.text('CURRENT PERIOD'), findsOneWidget);
    expect(find.text('26 Nov 2026 → 26 Dec 2026'), findsOneWidget);
    expect(find.text('NEXT BILLING DATE'), findsOneWidget);
    expect(find.text('26 Dec 2026'), findsOneWidget);
    expect(find.text('ctm_01abc'), findsOneWidget);
    // Cancelling is done on the web page, not here.
    expect(find.text('Cancel subscription on the web'), findsOneWidget);
  });

  testWidgets('a scheduled cancel says when access ends; resume is offered', (
    tester,
  ) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(cancelAt: '2026-12-26T12:00:00Z'),
    );
    final opened = <Uri>[];
    await _pump(tester, _host(gateway, opened: opened));

    expect(find.text('CANCELS ON'), findsOneWidget);
    expect(
      find.text(
        "Your subscription will end on 26 Dec 2026. You'll keep access "
        'until then.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Resume subscription on the web'));
    await tester.pump();
    expect(opened.single.path, '/app/billing');
  });

  testWidgets('self-serve plans are listed, the current one marked', (
    tester,
  ) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(),
      upgradeable: [canopy, heritage],
      features: const {
        'heritage': PlanBlurb(
          blurb: 'For families and advisors.',
          features: ['Advisor seat', 'Priority support'],
        ),
      },
    );
    final opened = <Uri>[];
    await _pump(tester, _host(gateway, opened: opened));

    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('Heritage'), findsOneWidget);
    expect(find.text('₹899.00 / month'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Upgrade to Canopy'), findsNothing);
    expect(find.text('For families and advisors.'), findsOneWidget);
    expect(find.text('Advisor seat'), findsOneWidget);
    expect(find.textContaining("Self-serve checkout isn't"), findsNothing);

    await tester.tap(find.text('Upgrade to Heritage'));
    await tester.pump();
    // Payment happens on the web page's checkout, in the browser.
    expect(opened.single.scheme, 'https');
    expect(opened.single.path, '/app/billing');
  });

  testWidgets('no purchasable plan: the catalogue and "Contact us"', (
    tester,
  ) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(),
      catalogueRows: [roots, canopy, heritage],
    );
    final opened = <Uri>[];
    await _pump(tester, _host(gateway, opened: opened));

    expect(
      find.textContaining("Self-serve checkout isn't available yet"),
      findsOneWidget,
    );
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('₹899 /mo'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Contact us'), findsNWidgets(2)); // Roots, Heritage
    expect(find.textContaining('Upgrade to'), findsNothing);

    await tester.tap(find.text('Contact us').last);
    await tester.pump();
    final mail = opened.single;
    expect(mail.scheme, 'mailto');
    expect(mail.path, kBillingSupportEmail);
    expect(mail.toString(), contains('subject=Upgrade%20to%20Heritage'));
    expect(mail.toString(), contains('Kumar%20Household'));
  });

  testWidgets('a viewer sees the plan read-only', (tester) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(
        role: 'viewer',
        transactions: [paidTxn('txn_1')],
      ),
      upgradeable: [canopy, heritage],
    );
    await _pump(tester, _host(gateway, role: WorkspaceRole.viewer));

    expect(find.text('Canopy'), findsWidgets);
    expect(find.text('Current plan'), findsOneWidget);
    expect(
      find.text('Only the workspace owner can change or cancel the plan.'),
      findsOneWidget,
    );
    expect(find.textContaining('Upgrade to'), findsNothing);
    expect(find.text('Cancel subscription on the web'), findsNothing);
    expect(find.text('INV-txn_1'), findsOneWidget);
    expect(find.byTooltip('Download receipt'), findsNothing);
  });

  testWidgets('billing-api decides the role: admin may get receipts only', (
    tester,
  ) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(
        role: 'admin',
        transactions: [
          paidTxn('txn_1'),
          paidTxn('txn_2', status: 'past_due'),
        ],
      ),
      upgradeable: [canopy, heritage],
    );
    final opened = <Uri>[];
    // The membership says owner; the function says admin, and wins.
    await _pump(tester, _host(gateway, opened: opened));

    expect(find.textContaining('Upgrade to'), findsNothing);
    expect(find.text('Cancel subscription on the web'), findsNothing);
    expect(find.text('2 records'), findsOneWidget);
    expect(find.text('PAST DUE'), findsOneWidget);

    final buttons = find.byTooltip('Download receipt');
    expect(buttons, findsNWidgets(2));
    // Only a paid transaction has a receipt.
    final pastDue = tester.widget<IconButton>(
      find.ancestor(of: buttons.last, matching: find.byType(IconButton)),
    );
    expect(pastDue.onPressed, isNull);

    await tester.tap(buttons.first);
    await tester.pumpAndSettle();
    expect(gateway.invoiceCalls.single, ('t1', 'txn_1'));
    expect(opened.single.toString(), gateway.invoice);
  });

  testWidgets('no subscription and no payments: empty state', (tester) async {
    final gateway = FakeBillingGateway(
      overviewJson: const {'subscription': null, 'transactions': <Object>[]},
    );
    await _pump(tester, _host(gateway));

    expect(find.text('No active plan'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);
    expect(find.text('No payments yet'), findsOneWidget);
    expect(
      find.text("Your invoices will appear here once you're charged."),
      findsOneWidget,
    );
    expect(find.text('Cancel subscription on the web'), findsNothing);
  });

  testWidgets('offline before anything loaded says so', (tester) async {
    // Offline, the live read fails too; the screen says why, not the error.
    final gateway = FakeBillingGateway(failOverview: const NetworkFailure());
    await _pump(tester, _host(gateway, online: false));
    expect(find.text("You're offline"), findsOneWidget);
    expect(
      find.text('Billing needs a connection. Connect, then pull to refresh.'),
      findsOneWidget,
    );
    expect(find.text('Canopy'), findsNothing);
  });

  testWidgets('going offline keeps what loaded but takes the actions away', (
    tester,
  ) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(transactions: [paidTxn('txn_1')]),
      upgradeable: [canopy, heritage],
    );
    await _pump(tester, _host(gateway));
    expect(find.text('Upgrade to Heritage'), findsOneWidget);

    await tester.pumpWidget(_host(gateway, online: false));
    await tester.pumpAndSettle();
    expect(
      find.text("You're offline — billing actions need a connection."),
      findsOneWidget,
    );
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Upgrade to Heritage'), findsNothing);
    expect(find.text('Cancel subscription on the web'), findsNothing);
    final receipt = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Download receipt'),
        matching: find.byType(IconButton),
      ),
    );
    expect(receipt.onPressed, isNull);
  });

  testWidgets('a load error is shown with a retry', (tester) async {
    final gateway = FakeBillingGateway(failOverview: const NetworkFailure());
    await _pump(tester, _host(gateway));

    expect(find.text(const NetworkFailure().message), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    gateway
      ..failOverview = null
      ..overviewJson = activeCanopy();
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('a plans error stays inside the plans section', (tester) async {
    final gateway = FakeBillingGateway(
      overviewJson: activeCanopy(),
      failPlans: const NetworkFailure(),
    );
    await _pump(tester, _host(gateway));

    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.textContaining("Couldn't load the plans."), findsOneWidget);
  });

  testWidgets('locked menu shows the locked view', (tester) async {
    final gateway = FakeBillingGateway(overviewJson: activeCanopy());
    await _pump(tester, _host(gateway, menus: const {'dashboard'}));
    expect(find.text("Billing isn't available"), findsOneWidget);
    expect(find.text('ACTIVE'), findsNothing);
  });
}
