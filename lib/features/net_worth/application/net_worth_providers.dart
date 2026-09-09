import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/application/workspace_providers.dart';
import '../data/net_worth_gateway.dart';
import '../domain/net_worth.dart';

final netWorthEntriesProvider = FutureProvider<List<NetWorthEntry>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(netWorthGatewayProvider).listEntries(tenantId);
}, name: 'netWorthEntries');

final netWorthTotalsProvider = Provider<NetWorthTotals>((ref) {
  final entries = ref.watch(netWorthEntriesProvider).value ?? const [];
  return NetWorthTotals.of(entries);
}, name: 'netWorthTotals');

/// The trend from `net_worth_snapshots`. Also records today's figures once —
/// so history accumulates just by opening the screen (web `useNetWorthHistory`).
final netWorthHistoryProvider = FutureProvider<List<NetWorthPoint>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  final gateway = ref.watch(netWorthGatewayProvider);

  // Fire-and-forget the snapshot using the totals we already have.
  final totals = ref.read(netWorthTotalsProvider);
  await gateway.recordSnapshot(
    tenantId,
    assets: totals.assets.amount.toDouble(),
    liabilities: totals.liabilities.amount.toDouble(),
  );

  return gateway.history(tenantId);
}, name: 'netWorthHistory');
