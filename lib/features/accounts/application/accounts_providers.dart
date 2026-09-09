import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../summary/application/summary_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/accounts_repository.dart';
import '../domain/account.dart';
import '../domain/account_balances.dart';

/// The active workspace's accounts, from the local cache. Empty when there is
/// no workspace.
final workspaceAccountsProvider = StreamProvider<List<AccountEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <AccountEntity>[]);
  return ref.watch(accountsRepositoryProvider).watchAll(tenantId);
}, name: 'workspaceAccounts');

/// One account by id, from the cache.
final accountByIdProvider = Provider.family<AccountEntity?, String>((ref, id) {
  final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}, name: 'accountById');

/// Live balance per account id: `opening_balance + server delta`
/// (`dashboard_summary`). Until the roll-up has loaded this is just the opening
/// balances — the UI shows a "needs a sync" hint in that case.
final accountBalancesProvider = Provider<Map<String, Money>>((ref) {
  final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
  final summary = ref.watch(workspaceSummaryProvider).value;

  final folded = applyAccountDeltas(
    [
      for (final a in accounts)
        BalanceAccount(id: a.id, openingBalance: a.openingBalance?.amount),
    ],
    summary?.accountDeltas,
  );
  return {
    for (final e in folded.entries) e.key: Money(e.value),
  };
}, name: 'accountBalances');

/// Sum of every account's live balance — the Home "total" figure.
final totalBalanceProvider = Provider<Money>((ref) {
  final balances = ref.watch(accountBalancesProvider);
  return balances.values.fold(Money.zero(), (sum, m) => sum + m);
}, name: 'totalBalance');
