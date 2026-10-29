import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/kv_cache_store.dart';
import '../../../domain/constants.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';

/// The workspace's own categories, in `tenant_settings` under
/// `custom_categories` — the same row the web dashboard's category manager
/// reads and writes (`src/lib/categories.ts`, `useCustomCategories`). Shape:
/// `{income: {active: [], passive: []}, expense: []}`. RLS: any member reads,
/// an admin or owner writes.
const customCategoriesSettingKey = 'custom_categories';

abstract interface class CustomCategoriesGateway {
  /// The stored JSON, or null when the workspace has never saved one.
  Future<Map<String, dynamic>?> load(String tenantId);
  Future<void> save(String tenantId, String? userId, Map<String, dynamic> value);
}

class SupabaseCustomCategoriesGateway implements CustomCategoriesGateway {
  SupabaseCustomCategoriesGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> load(String tenantId) async {
    try {
      final row = await _client
          .from('tenant_settings')
          .select('value')
          .eq('tenant_id', tenantId)
          .eq('key', customCategoriesSettingKey)
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
        'key': customCategoriesSettingKey,
        'value': value,
        'updated_by': userId,
      }, onConflict: 'tenant_id,key');
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final customCategoriesGatewayProvider = Provider<CustomCategoriesGateway>(
  (ref) => SupabaseCustomCategoriesGateway(ref.watch(supabaseClientProvider)),
  name: 'customCategoriesGateway',
);

/// The custom expense names in a stored value; anything malformed reads as none.
List<String> parseCustomExpense(Object? value) {
  final list = value is Map ? value['expense'] : null;
  if (list is! List) return const [];
  return [
    for (final e in list)
      if (e is String && e.trim().isNotEmpty) e.trim(),
  ];
}

/// [value] with [name] added to its expense list; income lists kept as stored.
Map<String, dynamic> withCustomExpense(Map<String, dynamic>? value, String name) {
  final v = Map<String, dynamic>.from(
    value ?? {'income': {'active': <String>[], 'passive': <String>[]}, 'expense': <String>[]},
  );
  v['expense'] = [...parseCustomExpense(v), name];
  v['income'] ??= {'active': <String>[], 'passive': <String>[]};
  return v;
}

/// Null when [raw] can be a new expense category next to [existing], else why not.
String? customCategoryProblem(String raw, List<String> existing) {
  final n = raw.trim();
  if (n.isEmpty) return 'Type a name for the category.';
  if (n.length > 40) return 'Keep the name under 40 characters.';
  final lower = n.toLowerCase();
  if ([...kExpenseCategories, ...existing].any((c) => c.toLowerCase() == lower)) {
    return '"$n" is already a category.';
  }
  return null;
}

/// The workspace's custom expense categories. Online: fetched and cached to
/// `kv_cache`; offline / error: the last cached copy.
class CustomExpenseCategories extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId == null) return const [];
    ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));
    final store = ref.watch(kvCacheStoreProvider);

    if (ref.watch(isOnlineProvider)) {
      try {
        final value = await ref.read(customCategoriesGatewayProvider).load(tenantId);
        await store.write(tenantId, customCategoriesSettingKey, jsonEncode(value));
        return parseCustomExpense(value);
      } on Failure {
        // fall through to cache
      }
    }
    final cached = await store.read(tenantId, customCategoriesSettingKey);
    return cached == null ? const [] : parseCustomExpense(jsonDecode(cached));
  }

  /// Saves [name] as a new expense category for the whole workspace (the web
  /// dashboard shows it too) and returns the trimmed name. Needs a connection.
  Future<String> add(String name) async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final problem = customCategoryProblem(name, state.value ?? const []);
    if (problem != null) throw ValidationFailure(problem);
    if (!ref.read(isOnlineProvider)) {
      throw const ValidationFailure('Connect to the internet to add a category.');
    }
    final n = name.trim();
    final gateway = ref.read(customCategoriesGatewayProvider);
    // Re-read first so a category added on the web meanwhile is kept.
    final next = withCustomExpense(await gateway.load(tenantId), n);
    await gateway.save(tenantId, ref.read(currentUserIdProvider), next);
    await ref.read(kvCacheStoreProvider).write(tenantId, customCategoriesSettingKey, jsonEncode(next));
    state = AsyncData(parseCustomExpense(next));
    return n;
  }
}

final customExpenseCategoriesProvider =
    AsyncNotifierProvider<CustomExpenseCategories, List<String>>(
  CustomExpenseCategories.new,
  name: 'customExpenseCategories',
);
