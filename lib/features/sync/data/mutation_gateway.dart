import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/app_database.dart';
import '../domain/sync_types.dart';

/// Sends one queued mutation to the server. Abstract so the outbox processor
/// can be tested without Supabase.
abstract interface class MutationGateway {
  /// Applies [entry] and returns the canonical outcome. Throws a mapped
  /// `Failure` on any backend error.
  Future<MutationResult> apply(OutboxEntry entry);
}

/// Calls `apply_transaction_mutation` (M1.5). The `mutation_id` in [entry] is
/// what makes a re-send safe — the RPC replays it instead of double-applying.
class SupabaseMutationGateway implements MutationGateway {
  SupabaseMutationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<MutationResult> apply(OutboxEntry entry) async {
    final envelope = <String, dynamic>{
      'mutation_id': entry.mutationId,
      'operation': entry.operation.wire,
      'tenant_id': entry.tenantId,
      'transaction_id': entry.entityLocalId,
      if (entry.payload != null)
        'payload': jsonDecode(entry.payload!) as Map<String, dynamic>,
    };
    try {
      final res = await _client.rpc<dynamic>(
        'apply_transaction_mutation',
        params: {'p_mutation': envelope},
      );
      if (res is Map<String, dynamic>) return MutationResult.fromRpc(res);
      if (res is Map) {
        return MutationResult.fromRpc(Map<String, dynamic>.from(res));
      }
      // A bare/unknown shape — treat as applied with no row to reconcile.
      return const MutationResult(status: 'applied', deleted: false);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final mutationGatewayProvider = Provider<MutationGateway>(
  (ref) => SupabaseMutationGateway(ref.watch(supabaseClientProvider)),
  name: 'mutationGateway',
);
