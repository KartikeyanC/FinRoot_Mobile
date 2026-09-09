import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/kv_cache_store.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/summary_gateway.dart';
import '../domain/workspace_summary.dart';

const _kSummaryCacheKey = 'dashboard_summary';

/// The active workspace's `dashboard_summary` roll-up.
///
/// Online: fetched fresh and written to `kv_cache`. Offline or on error: the
/// last cached copy, so account balances still read sensibly without a
/// connection (M1 audit §"roll-ups fetched fresh… cached"). Invalidate it
/// after a transaction write or a completed sync to pull new figures.
final workspaceSummaryProvider = FutureProvider<WorkspaceSummary>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return WorkspaceSummary.empty();

  // Refetch whenever a sync completes — that is when server-side figures
  // (and therefore account balances) can have moved.
  ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));

  final store = ref.watch(kvCacheStoreProvider);

  if (ref.watch(isOnlineProvider)) {
    try {
      final fresh = await ref.watch(summaryGatewayProvider).fetch(tenantId);
      await store.write(
        tenantId,
        _kSummaryCacheKey,
        jsonEncode(fresh.toCache()),
      );
      return fresh;
    } on Failure {
      // fall through to whatever we last cached
    }
  }

  final cached = await store.read(tenantId, _kSummaryCacheKey);
  if (cached != null) {
    return WorkspaceSummary.fromCache(
      jsonDecode(cached) as Map<String, dynamic>,
    );
  }
  return WorkspaceSummary.empty();
}, name: 'workspaceSummary');
