import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/kv_cache_store.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/expense_subcategories.dart';

/// The workspace's own subcategories, in `tenant_settings` under
/// `custom_subcategories` — the row the web dashboard writes
/// (`useCustomSubcategories`). Shape: `{groupName: [sub, ...]}`. RLS: any member
/// reads, an admin or owner writes.
const customSubcategoriesSettingKey = 'custom_subcategories';

abstract interface class CustomSubcategoriesGateway {
  Future<Map<String, dynamic>?> load(String tenantId);
  Future<void> save(String tenantId, String? userId, Map<String, dynamic> value);
}

class SupabaseCustomSubcategoriesGateway implements CustomSubcategoriesGateway {
  SupabaseCustomSubcategoriesGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> load(String tenantId) async {
    try {
      final row = await _client
          .from('tenant_settings')
          .select('value')
          .eq('tenant_id', tenantId)
          .eq('key', customSubcategoriesSettingKey)
          .maybeSingle();
      final v = row?['value'];
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> save(String tenantId, String? userId, Map<String, dynamic> value) async {
    try {
      await _client.from('tenant_settings').upsert({
        'tenant_id': tenantId,
        'key': customSubcategoriesSettingKey,
        'value': value,
        'updated_by': userId,
      }, onConflict: 'tenant_id,key');
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final customSubcategoriesGatewayProvider = Provider<CustomSubcategoriesGateway>(
  (ref) => SupabaseCustomSubcategoriesGateway(ref.watch(supabaseClientProvider)),
  name: 'customSubcategoriesGateway',
);

/// Null when [raw] can be a new sub of web [group], else why not.
String? customSubcategoryProblem(
  String raw,
  String group,
  Map<String, List<String>> store,
) {
  final n = raw.trim();
  if (n.isEmpty) return 'Type a name for the subcategory.';
  if (n.length > 40) return 'Keep the name under 40 characters.';
  final lower = n.toLowerCase();
  final existing = [
    for (final g in kExpenseGroups)
      if (g.name == group) ...g.subs,
    ...?store[group],
  ];
  if (existing.any((s) => s.toLowerCase() == lower)) {
    return '"$n" is already a subcategory.';
  }
  return null;
}

/// The custom subs by group. Online: fetched and cached to `kv_cache`;
/// offline / error: the last cached copy.
class CustomSubcategories extends AsyncNotifier<Map<String, List<String>>> {
  @override
  Future<Map<String, List<String>>> build() async {
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId == null) return const {};
    ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));
    final store = ref.watch(kvCacheStoreProvider);

    if (ref.watch(isOnlineProvider)) {
      try {
        final value = await ref.read(customSubcategoriesGatewayProvider).load(tenantId);
        await store.write(tenantId, customSubcategoriesSettingKey, jsonEncode(value));
        return parseCustomSubcategories(value);
      } on Failure {
        // fall through to cache
      }
    }
    final cached = await store.read(tenantId, customSubcategoriesSettingKey);
    return cached == null ? const {} : parseCustomSubcategories(cached);
  }

  /// Adds [name] under web [group] for the whole workspace and returns the
  /// trimmed name. Re-reads first so subs added on the web meanwhile are kept.
  Future<String> add(String group, String name) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    if (!ref.read(isOnlineProvider)) {
      throw const ValidationFailure('Connect to the internet to add a subcategory.');
    }
    final gateway = ref.read(customSubcategoriesGatewayProvider);
    final current = parseCustomSubcategories(await gateway.load(tenantId));
    final problem = customSubcategoryProblem(name, group, current);
    if (problem != null) throw ValidationFailure(problem);
    final n = name.trim();
    await _write(tenantId, gateway, {
      ...current,
      group: [...?current[group], n],
    });
    return n;
  }

  /// Removes [name] from each of [groups] (the keys it may be filed under).
  Future<void> remove(Iterable<String> groups, String name) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    if (!ref.read(isOnlineProvider)) {
      throw const ValidationFailure('Connect to the internet to remove a subcategory.');
    }
    final gateway = ref.read(customSubcategoriesGatewayProvider);
    final current = parseCustomSubcategories(await gateway.load(tenantId));
    final lower = name.toLowerCase();
    await _write(tenantId, gateway, {
      for (final e in current.entries)
        e.key: groups.contains(e.key)
            ? [
                for (final s in e.value)
                  if (s.toLowerCase() != lower) s,
              ]
            : e.value,
    });
  }

  Future<void> _write(
    String tenantId,
    CustomSubcategoriesGateway gateway,
    Map<String, List<String>> next,
  ) async {
    await gateway.save(tenantId, ref.read(currentUserIdProvider), next);
    await ref
        .read(kvCacheStoreProvider)
        .write(tenantId, customSubcategoriesSettingKey, jsonEncode(next));
    state = AsyncData(next);
  }
}

final customSubcategoriesProvider =
    AsyncNotifierProvider<CustomSubcategories, Map<String, List<String>>>(
  CustomSubcategories.new,
  name: 'customSubcategories',
);
