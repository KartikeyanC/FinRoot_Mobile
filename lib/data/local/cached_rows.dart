import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/providers/providers.dart';
import '../../features/sync/application/sync_engine.dart';
import '../../features/workspace/application/workspace_providers.dart';
import 'kv_cache_store.dart';

/// Rows of a table the sync engine doesn't mirror (debts, subscriptions,
/// insurance…), for the active workspace. Online: [fetch] runs and the rows
/// are cached to `kv_cache` under [cacheKey]; offline or on error: the last
/// cached copy, so the screen still shows something. Refetches after every
/// completed sync, like the other server-derived lists (tracker spend).
///
/// Call from a provider body: it watches the tenant, connectivity and sync.
Future<List<Map<String, dynamic>>> watchCachedRows(
  Ref ref,
  String cacheKey,
  Future<List<Map<String, dynamic>>> Function(String tenantId) fetch,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));
  final store = ref.watch(kvCacheStoreProvider);

  if (ref.watch(isOnlineProvider)) {
    try {
      final rows = await fetch(tenantId);
      await store.write(tenantId, cacheKey, jsonEncode(rows));
      return rows;
    } on Failure {
      // fall through to cache
    }
  }
  final cached = await store.read(tenantId, cacheKey);
  if (cached == null) return const [];
  return [
    for (final r in jsonDecode(cached) as List<dynamic>) Map<String, dynamic>.from(r as Map),
  ];
}

/// A Postgres `numeric` as it arrives over PostgREST (number or string).
double asDouble(Object? v) => switch (v) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

/// A `date` / `timestamptz` column, or null.
DateTime? asDate(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
