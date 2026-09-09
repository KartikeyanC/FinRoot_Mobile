import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/sync_types.dart';

/// Fetches server rows for a delta or full pull. Abstract so the puller is
/// testable without Supabase.
abstract interface class PullGateway {
  /// Rows for [entity] in [tenantId] changed strictly after [since] (null =
  /// from the beginning / a full sync), ascending by `updated_at`, at most
  /// [limit]. [transactionWindowStart] bounds a full transaction pull so the
  /// cache does not try to hold years of history.
  Future<PullPage> fetchSince(
    SyncEntity entity,
    String tenantId, {
    required DateTime? since,
    required int limit,
    DateTime? transactionWindowStart,
  });

  /// All row ids currently on the server for [entity] in [tenantId] (transactions
  /// bounded by [transactionWindowStart]). Used by a full sync to prune cache
  /// rows the server no longer has (a web-side hard delete).
  Future<Set<String>> fetchLiveIds(
    SyncEntity entity,
    String tenantId, {
    DateTime? transactionWindowStart,
  });
}

class SupabasePullGateway implements PullGateway {
  SupabasePullGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<PullPage> fetchSince(
    SyncEntity entity,
    String tenantId, {
    required DateTime? since,
    required int limit,
    DateTime? transactionWindowStart,
  }) async {
    try {
      var query = _client.from(entity.table).select().eq('tenant_id', tenantId);
      if (since != null) {
        query = query.gt('updated_at', since.toUtc().toIso8601String());
      }
      if (entity == SyncEntity.transaction && transactionWindowStart != null) {
        query = query.gte(
          'occurred_at',
          transactionWindowStart.toUtc().toIso8601String(),
        );
      }
      final rows = await query
          .order('updated_at', ascending: true)
          .limit(limit);
      final list = List<Map<String, dynamic>>.from(rows);
      return PullPage(rows: list, hasMore: list.length >= limit);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<Set<String>> fetchLiveIds(
    SyncEntity entity,
    String tenantId, {
    DateTime? transactionWindowStart,
  }) async {
    try {
      var query = _client
          .from(entity.table)
          .select('id')
          .eq('tenant_id', tenantId);
      if (entity == SyncEntity.transaction && transactionWindowStart != null) {
        query = query.gte(
          'occurred_at',
          transactionWindowStart.toUtc().toIso8601String(),
        );
      }
      final rows = await query;
      return {for (final r in rows) r['id'] as String};
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final pullGatewayProvider = Provider<PullGateway>(
  (ref) => SupabasePullGateway(ref.watch(supabaseClientProvider)),
  name: 'pullGateway',
);
