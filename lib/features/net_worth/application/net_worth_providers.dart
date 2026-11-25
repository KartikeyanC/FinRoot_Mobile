import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/accounts_providers.dart';
import '../../debts/debts.dart';
import '../../investments/application/investments_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/net_worth_gateway.dart';
import '../domain/net_worth.dart';
import '../domain/net_worth_synced.dart';

final netWorthEntriesProvider = FutureProvider<List<NetWorthEntry>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(netWorthGatewayProvider).listEntries(tenantId);
}, name: 'netWorthEntries');

/// Accounts, investments and loans as read-only rows. A source that can't be
/// read (offline, or a menu the plan leaves out) adds nothing.
final netWorthSyncedProvider = Provider<List<NetWorthEntry>>((ref) {
  return syncedNetWorth(
    accounts: ref.watch(workspaceAccountsProvider).value ?? const [],
    balances: ref.watch(accountBalancesProvider),
    investments: ref.watch(investmentsProvider).value ?? const [],
    debts: ref.watch(debtsProvider).value ?? const [],
  );
}, name: 'netWorthSynced');

/// The person's rows, then the synced ones.
final netWorthAllEntriesProvider = Provider<List<NetWorthEntry>>((ref) {
  return [
    ...ref.watch(netWorthEntriesProvider).value ?? const <NetWorthEntry>[],
    ...ref.watch(netWorthSyncedProvider),
  ];
}, name: 'netWorthAllEntries');

final netWorthTotalsProvider = Provider<NetWorthTotals>((ref) {
  return NetWorthTotals.of(ref.watch(netWorthAllEntriesProvider));
}, name: 'netWorthTotals');

/// The trend from `net_worth_snapshots`. Also records today's figures once —
/// so history accumulates just by opening the screen (web `useNetWorthHistory`).
final netWorthHistoryProvider = FutureProvider<List<NetWorthPoint>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  final gateway = ref.watch(netWorthGatewayProvider);

  // Today's snapshot is shared with the web, which counts accounts,
  // investments and loans: wait for them, so a half-loaded figure is never
  // the one recorded.
  Future<void> settle(Future<Object?> f) => f.then((_) {}, onError: (_) {});
  await Future.wait([
    settle(ref.read(netWorthEntriesProvider.future)),
    settle(ref.read(workspaceAccountsProvider.future)),
    settle(ref.read(investmentsProvider.future)),
    settle(ref.read(debtsProvider.future)),
  ]);
  final totals = ref.read(netWorthTotalsProvider);
  await gateway.recordSnapshot(
    tenantId,
    assets: totals.assets.amount.toDouble(),
    liabilities: totals.liabilities.amount.toDouble(),
  );

  return gateway.history(tenantId);
}, name: 'netWorthHistory');
