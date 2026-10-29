import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/logging/app_logger.dart';
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

/// The table writes a mutation needs when `apply_transaction_mutation` is not
/// on the server. Abstract so the fallback can be tested without Supabase.
abstract interface class DirectTransactionWriter {
  /// Insert with the given `id`; returns the stored row. A row with that id
  /// already existing must surface as a PostgrestException with code 23505.
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row);
  Future<Map<String, dynamic>?> select(String tenantId, String id);
  Future<Map<String, dynamic>?> update(String tenantId, String id, Map<String, dynamic> fields);
  Future<void> delete(String tenantId, String id);
  String? currentUserId();
}

class SupabaseDirectTransactionWriter implements DirectTransactionWriter {
  SupabaseDirectTransactionWriter(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> row) async =>
      Map<String, dynamic>.from(
        await _client.from('transactions').insert(row).select().single(),
      );

  @override
  Future<Map<String, dynamic>?> select(String tenantId, String id) async {
    final r = await _client
        .from('transactions')
        .select()
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .maybeSingle();
    return r == null ? null : Map<String, dynamic>.from(r);
  }

  @override
  Future<Map<String, dynamic>?> update(
    String tenantId,
    String id,
    Map<String, dynamic> fields,
  ) async {
    final r = await _client
        .from('transactions')
        .update(fields)
        .eq('id', id)
        .eq('tenant_id', tenantId)
        .select()
        .maybeSingle();
    return r == null ? null : Map<String, dynamic>.from(r);
  }

  @override
  Future<void> delete(String tenantId, String id) =>
      _client.from('transactions').delete().eq('id', id).eq('tenant_id', tenantId);

  @override
  String? currentUserId() => _client.auth.currentUser?.id;
}

/// Calls `apply_transaction_mutation` (M1.5). The `mutation_id` in [entry] is
/// what makes a re-send safe — the RPC replays it instead of double-applying.
///
/// **Fallback while M1.5 is not applied.** The live project has never had
/// that migration (it waits in `backend/`), so the RPC answers PGRST202 and
/// every phone write stayed "Pending" ("The last sync didn't finish"). When
/// that happens the change is written straight to `transactions` instead,
/// under the same RLS (`is_tenant_member(_, 'admin')`). Still safe to retry:
/// a create uses the phone's own transaction id — exactly what the RPC does —
/// so a second attempt hits the primary key (23505) and is treated as already
/// applied; updates and deletes by id are naturally repeatable. Once the
/// migration is applied the RPC answers and this path is no longer taken.
class SupabaseMutationGateway implements MutationGateway {
  SupabaseMutationGateway(this._client, [DirectTransactionWriter? direct])
    : _direct = direct ?? SupabaseDirectTransactionWriter(_client);

  final SupabaseClient _client;
  final DirectTransactionWriter _direct;
  final _log = AppLog.of('sync.gateway');

  /// Set once the RPC answered "not found", so later entries skip the probe.
  bool _rpcMissing = false;

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
      if (!_rpcMissing) {
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
        } on PostgrestException catch (e) {
          if (e.code != 'PGRST202') rethrow;
          _rpcMissing = true;
          _log.info('apply_transaction_mutation not deployed — writing directly');
        }
      }
      return await applyDirect(_direct, envelope);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

String? _blankToNull(Object? v) {
  final s = v?.toString();
  return (s == null || s.trim().isEmpty) ? null : s;
}

/// The row fields a create/update writes — the same mapping the RPC uses.
Map<String, dynamic> transactionFields(Map<String, dynamic> p) => {
  'type': p['type'],
  'amount': p['amount'],
  'currency': _blankToNull(p['currency']) ?? 'INR',
  'category': p['category'],
  'description': _blankToNull(p['description']),
  if (_blankToNull(p['occurred_at']) != null) 'occurred_at': p['occurred_at'],
  'account_id': _blankToNull(p['account_id']),
  'payment_mode': _blankToNull(p['payment_mode']),
  'transfer_to_account_id': _blankToNull(p['transfer_to_account_id']),
  'tracker_id': _blankToNull(p['tracker_id']),
};

/// Applies one mutation envelope with plain table writes (see the fallback
/// note on [SupabaseMutationGateway]). Returns what the RPC would have.
Future<MutationResult> applyDirect(
  DirectTransactionWriter db,
  Map<String, dynamic> envelope,
) async {
  final op = envelope['operation'] as String?;
  final tenantId = envelope['tenant_id'] as String;
  final id = envelope['transaction_id'] as String?;
  final payload = (envelope['payload'] as Map?)?.cast<String, dynamic>() ?? const {};

  switch (op) {
    case 'create_transaction':
      final row = {
        'id': id,
        'tenant_id': tenantId,
        'user_id': db.currentUserId(),
        ...transactionFields(payload),
      };
      try {
        final saved = await db.insert(row);
        return MutationResult(status: 'applied', deleted: false, transaction: saved);
      } on PostgrestException catch (e) {
        // Already created by an earlier attempt whose reply was lost.
        if (e.code != '23505' || id == null) rethrow;
        return MutationResult(
          status: 'replayed',
          deleted: false,
          transaction: await db.select(tenantId, id),
        );
      }
    case 'update_transaction':
      final saved = await db.update(tenantId, id!, transactionFields(payload));
      if (saved == null) {
        throw PostgrestException(
          message: 'no transaction $id in this workspace',
          code: 'P0002',
        );
      }
      return MutationResult(status: 'applied', deleted: false, transaction: saved);
    case 'delete_transaction':
      await db.delete(tenantId, id!);
      return const MutationResult(status: 'applied', deleted: true);
    default:
      throw PostgrestException(message: 'unknown operation: $op', code: '22023');
  }
}

final mutationGatewayProvider = Provider<MutationGateway>(
  (ref) => SupabaseMutationGateway(ref.watch(supabaseClientProvider)),
  name: 'mutationGateway',
);
