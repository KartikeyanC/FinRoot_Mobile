import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/account_draft.dart';

const _uuid = Uuid();

/// Account writes. Unlike transactions (which go through the offline outbox +
/// `apply_transaction_mutation`), accounts have no offline queue in V1 — they
/// write straight to PostgREST under RLS, exactly like the web
/// (`src/lib/accountsStore.ts`). A mobile edit PATCHes only the columns it
/// manages so web-only fields (bank, holder, colour…) are never cleared.
///
/// Abstract so the controller can be tested without Supabase.
abstract interface class AccountWriteGateway {
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    AccountDraft draft,
  );

  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    AccountDraft draft,
  );

  Future<void> delete(String tenantId, String id);
}

class SupabaseAccountWriteGateway implements AccountWriteGateway {
  SupabaseAccountWriteGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    AccountDraft draft,
  ) async {
    try {
      final row = await _client
          .from('accounts')
          .insert({
            'id': _uuid.v4(),
            'tenant_id': tenantId,
            'user_id': ?userId,
            'name': draft.name.trim(),
            'type': draft.type,
            'opening_balance': draft.openingBalance?.amount.toDouble(),
            'opening_date': _today(),
          })
          .select()
          .single();
      return row;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    AccountDraft draft,
  ) async {
    try {
      final row = await _client
          .from('accounts')
          .update({
            'name': draft.name.trim(),
            'type': draft.type,
            'opening_balance': draft.openingBalance?.amount.toDouble(),
          })
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .select()
          .single();
      return row;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    try {
      await _client
          .from('accounts')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }
}

final accountWriteGatewayProvider = Provider<AccountWriteGateway>(
  (ref) => SupabaseAccountWriteGateway(ref.watch(supabaseClientProvider)),
  name: 'accountWriteGateway',
);
