import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/net_worth/application/net_worth_providers.dart';
import 'package:finroot_mobile/features/net_worth/domain/net_worth.dart';
import 'package:finroot_mobile/features/net_worth/presentation/net_worth_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NetWorthEntry _e(String id, String kind, String group, String amount) =>
    NetWorthEntry(
      id: id,
      kind: kind,
      group: group,
      name: id,
      amount: Money.parse(amount),
    );

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<NetWorthEntry> entries = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.netWorth).overrideWithValue(menu),
      netWorthEntriesProvider.overrideWith((ref) async => entries),
      netWorthHistoryProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const NetWorthScreen()),
  );
}

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('shows net worth = assets - liabilities and groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        entries: [
          _e('SBI', 'asset', 'bank', '600000'),
          _e('Flat EMI', 'liability', 'home_loan', '150000'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Net worth'), findsWidgets); // app bar + headline card
    expect(find.text('Assets'), findsOneWidget);
    expect(find.text('Liabilities'), findsOneWidget);
    expect(find.text('SBI'), findsOneWidget);
    // 600,000 - 150,000 = ₹4.50L
    expect(find.textContaining('4.50L'), findsWidgets);
  });

  testWidgets('empty state prompts to add', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('Build the picture'), findsOneWidget);
  });
}
