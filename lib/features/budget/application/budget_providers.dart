import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/kv_cache_store.dart';
import '../../../domain/constants.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/budget_gateways.dart';
import '../data/budgets_repository.dart';
import '../domain/budget_buckets.dart';
import '../domain/budget_spend.dart';

/// The month the Budget screen is showing (UTC first-of-month). V1 is
/// month-only; a picker can widen this later.
final budgetPeriodProvider = Provider<DateTime>(
  (ref) => currentMonthStart(),
  name: 'budgetPeriod',
);

final budgetsForPeriodProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <BudgetEntity>[]);
  return ref
      .watch(budgetsRepositoryProvider)
      .watchForPeriod(tenantId, ref.watch(budgetPeriodProvider));
}, name: 'budgetsForPeriod');

const _kBudgetSpendKey = 'budget_spend';

final budgetSpendRowsProvider = FutureProvider<List<BudgetSpendRow>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];

  ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));
  final store = ref.watch(kvCacheStoreProvider);

  if (ref.watch(isOnlineProvider)) {
    try {
      final rows = await ref.watch(budgetSpendGatewayProvider).fetch(tenantId);
      await store.write(
        tenantId,
        _kBudgetSpendKey,
        jsonEncode([
          for (final r in rows)
            {
              'budget_id': r.budgetId,
              'category': r.category,
              'total': r.total.toString(),
              'count': r.count,
            },
        ]),
      );
      return rows;
    } on Failure {
      // fall through to cache
    }
  }

  final cached = await store.read(tenantId, _kBudgetSpendKey);
  if (cached != null) {
    return [
      for (final r in jsonDecode(cached) as List<dynamic>)
        BudgetSpendRow.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }
  return const [];
}, name: 'budgetSpendRows');

/// The current period's buckets, spend folded on. Buckets with no budget row
/// yet are synthesised so the whole 7-jar system is always visible.
final budgetsWithSpendProvider = Provider<AsyncValue<List<BudgetWithSpend>>>((
  ref,
) {
  final budgets = ref.watch(budgetsForPeriodProvider);
  final rows = ref.watch(budgetSpendRowsProvider).value;
  final period = ref.watch(budgetPeriodProvider);

  return budgets.whenData((list) {
    final byBucket = {for (final b in list) b.bucket: b};
    final full = [
      for (final bucket in kBudgetBuckets)
        byBucket[bucket] ??
            BudgetEntity(
              id: 'unset:$bucket',
              bucket: bucket,
              allocated: Money.zero(),
              period: 'monthly',
              periodStart: period,
            ),
    ];
    return foldBudgetSpend(full, rows);
  });
}, name: 'budgetsWithSpend');
