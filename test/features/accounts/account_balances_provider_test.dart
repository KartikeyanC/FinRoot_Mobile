import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/accounts/domain/account_balances.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AccountEntity _acc(String id, String opening) => AccountEntity(
  id: id,
  name: id.toUpperCase(),
  type: 'bank',
  openingBalance: Money.parse(opening),
);

ProviderContainer _container({
  required List<AccountEntity> accounts,
  List<AccountDelta>? deltas,
}) {
  final summary = WorkspaceSummary(
    accountDeltas: deltas ?? const [],
    monthIncome: Money.zero(),
    monthExpense: Money.zero(),
    transactionCount: 0,
    fetchedAt: DateTime(2026, 9, 9),
  );
  final c = ProviderContainer(
    overrides: [
      workspaceAccountsProvider.overrideWithValue(AsyncValue.data(accounts)),
      workspaceSummaryProvider.overrideWithValue(AsyncValue.data(summary)),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('balance = opening + server delta, per account', () async {
    final c = _container(
      accounts: [_acc('sbi', '100000'), _acc('cash', '4000')],
      deltas: [
        AccountDelta(accountId: 'sbi', delta: Decimal.parse('12000')),
        AccountDelta(accountId: 'cash', delta: Decimal.parse('-500')),
      ],
    );

    final balances = c.read(accountBalancesProvider);
    expect(balances['sbi']!.amount, Decimal.parse('112000'));
    expect(balances['cash']!.amount, Decimal.parse('3500'));
    expect(c.read(totalBalanceProvider).amount, Decimal.parse('115500'));
  });

  test('without the roll-up yet, balances are the opening figures', () async {
    final c = _container(
      accounts: [_acc('sbi', '100000')],
      // no deltas → summary empty
    );
    expect(c.read(accountBalancesProvider)['sbi']!.amount, Decimal.parse('100000'));
    expect(c.read(totalBalanceProvider).amount, Decimal.parse('100000'));
  });

  test('a delta for an account that is gone does not invent a balance', () async {
    final c = _container(
      accounts: [_acc('sbi', '100000')],
      deltas: [AccountDelta(accountId: 'deleted', delta: Decimal.parse('9999'))],
    );
    final balances = c.read(accountBalancesProvider);
    expect(balances.containsKey('deleted'), isFalse);
    expect(c.read(totalBalanceProvider).amount, Decimal.parse('100000'));
  });
}
