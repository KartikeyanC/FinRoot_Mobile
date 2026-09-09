import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/investments_gateway.dart';
import '../domain/investment.dart';

/// The workspace's investment holdings — live from PostgREST (not cached).
/// Invalidate to refresh.
final investmentsProvider = FutureProvider<List<InvestmentRecord>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(investmentsGatewayProvider).list(tenantId);
}, name: 'investments');

class PortfolioSummary {
  const PortfolioSummary({
    required this.invested,
    required this.current,
    required this.byAsset,
  });

  final Money invested;
  final Money current;

  /// asset → current value, largest first.
  final List<MapEntry<String, Money>> byAsset;

  Money get gain => current - invested;
  double get returnPct {
    final i = invested.amount.toDouble();
    return i == 0 ? 0 : (gain.amount.toDouble() / i * 100);
  }
}

final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final records = ref.watch(investmentsProvider).value ?? const [];
  var invested = Money.zero();
  var current = Money.zero();
  final byAsset = <String, Money>{};
  for (final r in records) {
    // V1 sums figures as-is (INR assumption, like the web portfolio totals).
    invested = invested + Money(r.invested.amount);
    current = current + Money(r.current.amount);
    byAsset[r.asset] =
        (byAsset[r.asset] ?? Money.zero()) + Money(r.current.amount);
  }
  final sorted = byAsset.entries.toList()
    ..sort((a, b) => b.value.amount.compareTo(a.value.amount));
  return PortfolioSummary(
    invested: invested,
    current: current,
    byAsset: sorted,
  );
}, name: 'portfolioSummary');
