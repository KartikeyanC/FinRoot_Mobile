import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/split/data/split_dues_gateway.dart';
import 'package:finroot_mobile/features/split/domain/split_dues.dart';
import 'package:finroot_mobile/features/split/presentation/who_owes_what_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'split_fakes.dart';

SplitDue _due(
  String id,
  String person,
  double amount, {
  DueDirection direction = DueDirection.owedToMe,
  String? settledAt,
  double settledAmount = 0,
  String? note,
}) => SplitDue(
  id: id,
  person: person,
  amount: amount,
  currency: 'INR',
  direction: direction,
  source: DueSource.split,
  createdAt: '2026-11-26T10:00:00Z',
  settledAt: settledAt,
  settledAmount: settledAmount,
  note: note,
);

Widget _host(
  FakeSplitDuesGateway gateway, {
  WorkspaceRole role = WorkspaceRole.owner,
  bool online = true,
}) => ProviderScope(
  overrides: [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(role),
    isOnlineProvider.overrideWithValue(online),
    splitDuesGatewayProvider.overrideWithValue(gateway),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const WhoOwesWhatScreen()),
);

void main() {
  testWidgets('missing table shows the database-update message', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeSplitDuesGateway(missing: true)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Ask the workspace owner to run the database update'),
      findsOneWidget,
    );
  });

  testWidgets('open dues per person with net totals; settle in full', (
    tester,
  ) async {
    final gateway = FakeSplitDuesGateway(
      dues: [
        _due('d1', 'Asha', 300, note: 'Dinner'),
        _due('d2', 'asha', 50, direction: DueDirection.iOwe),
        _due('d3', 'Ravi', 120),
        _due('d4', 'Kiran', 80, settledAt: '2026-11-25T10:00:00Z'),
      ],
    );
    await tester.pumpWidget(_host(gateway));
    await tester.pumpAndSettle();

    expect(find.text('Asha'), findsOneWidget);
    expect(find.textContaining('Owes you ₹250'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('Kiran'), findsNothing); // settled: history only
    expect(find.text('Owed to you'), findsOneWidget);

    await tester.tap(find.text('Settle').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settle all'));
    await tester.pumpAndSettle();
    expect(gateway.settled.single, ('d1', null));
  });

  testWidgets('partial settle sends the amount', (tester) async {
    final gateway = FakeSplitDuesGateway(dues: [_due('d1', 'Asha', 300)]);
    await tester.pumpWidget(_host(gateway));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settle-amount')), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Settle'));
    await tester.pumpAndSettle();
    expect(gateway.settled.single, ('d1', 100.0));
  });

  testWidgets('settled history tab', (tester) async {
    final gateway = FakeSplitDuesGateway(
      dues: [_due('d4', 'Kiran', 80, settledAt: '2026-11-25T10:00:00Z')],
    );
    await tester.pumpWidget(_host(gateway));
    await tester.pumpAndSettle();
    expect(find.text('All square'), findsOneWidget);
    await tester.tap(find.text('Settled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Kiran'), findsOneWidget);
  });

  testWidgets('viewer is read-only', (tester) async {
    final gateway = FakeSplitDuesGateway(dues: [_due('d1', 'Asha', 300)]);
    await tester.pumpWidget(_host(gateway, role: WorkspaceRole.viewer));
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Settle'), findsNothing);
    expect(find.text('Split'), findsNothing);
  });

  testWidgets('offline before anything loaded says so', (tester) async {
    await tester.pumpWidget(_host(FakeSplitDuesGateway(), online: false));
    expect(find.text("You're offline"), findsOneWidget);
  });
}
