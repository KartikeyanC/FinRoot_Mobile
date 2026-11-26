import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/split_dues.dart';

/// `split_dues` (or `split_due_settle()`) is not in the database yet: the
/// migration has not been applied. Screens show [kSplitDuesMissingMessage].
class SplitDuesMissing implements Exception {
  const SplitDuesMissing();

  String get message => kSplitDuesMissingMessage;

  @override
  String toString() => 'SplitDuesMissing';
}

/// `split_dues` — live PostgREST, not cached (like the web's useSplitDues).
abstract interface class SplitDuesGateway {
  /// Newest first, up to 500 (web limit).
  Future<List<SplitDue>> list(String tenantId);

  Future<void> insert(String tenantId, List<NewSplitDue> rows);

  /// Settle one due fully ([amount] null) or partly — one locked UPDATE on
  /// the server (`split_due_settle`), never a read-add-write here.
  Future<void> settle(String id, {double? amount});
}

class SupabaseSplitDuesGateway implements SplitDuesGateway {
  SupabaseSplitDuesGateway(this._client);
  final SupabaseClient _client;

  Never _rethrow(Object error, StackTrace stack) {
    if (error is PostgrestException &&
        isSplitDuesMissing(code: error.code, message: error.message)) {
      throw const SplitDuesMissing();
    }
    throw mapError(error, stack);
  }

  @override
  Future<List<SplitDue>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('split_dues')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(500);
      return [
        for (final r in rows as List)
          SplitDue.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }

  @override
  Future<void> insert(String tenantId, List<NewSplitDue> rows) async {
    if (rows.isEmpty) return;
    final now = DateTime.now();
    try {
      await _client.from('split_dues').insert([
        for (final r in rows) r.toInsert(tenantId, now),
      ]);
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }

  @override
  Future<void> settle(String id, {double? amount}) async {
    try {
      await _client.rpc<dynamic>(
        'split_due_settle',
        params: {'p_id': id, 'p_amount': amount},
      );
    } catch (error, stack) {
      _rethrow(error, stack);
    }
  }
}

final splitDuesGatewayProvider = Provider<SplitDuesGateway>(
  (ref) => SupabaseSplitDuesGateway(ref.watch(supabaseClientProvider)),
  name: 'splitDuesGateway',
);
