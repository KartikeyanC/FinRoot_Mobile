import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/accounts/domain/account_balances.dart';
import 'package:finroot_mobile/features/accounts/presentation/accounts_screen.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AccountEntity _acc(String id, String name, String opening) => AccountEntity(
  id: id,
  name: name,
  type: 'bank',
  openingBalance: Money.parse(opening),
);

Widget _host({
  required List<AccountEntity> accounts,
  List<AccountDelta> deltas = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      workspaceAccountsProvider.overrideWithValue(AsyncValue.data(accounts)),
      workspaceSummaryProvider.overrideWithValue(
        AsyncValue.data(
          WorkspaceSummary(
            accountDeltas: deltas,
            monthIncome: Money.zero(),
            monthExpense: Money.zero(),
            transactionCount: 0,
            fetchedAt: DateTime(2026, 9, 9),
          ),
        ),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const AccountsScreen()),
  );
}

void main() {
  testWidgets('lists accounts with a computed total', (tester) async {
    await tester.pumpWidget(
      _host(
        accounts: [_acc('sbi', 'SBI', '100000'), _acc('cash', 'Cash', '5000')],
        deltas: [AccountDelta(accountId: 'sbi', delta: Decimal.parse('20000'))],
      ),
    );
    await tester.pump();

    expect(find.text('SBI'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('TOTAL ACROSS ACCOUNTS'), findsOneWidget);
    // 120,000 + 5,000 = ₹1.25L (hero short form)
    expect(find.textContaining('1.25L'), findsOneWidget);
  });

  testWidgets('no accounts shows the add-account empty state', (tester) async {
    await tester.pumpWidget(_host(accounts: const []));
    await tester.pump();

    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add an account'), findsOneWidget);
  });
}
