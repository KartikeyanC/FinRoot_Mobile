import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/goal_draft.dart';

const _uuid = Uuid();

/// Goal writes. Create / update / delete are direct PostgREST; **contribute**
/// goes through the `goal_contribute` RPC, which locks the row and owns the
/// invariants (never below zero, never past target, status flips itself —
/// web BUG-040). Online-only in V1.
abstract interface class GoalWriteGateway {
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    GoalDraft draft,
  );
  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    GoalDraft draft,
  );
  Future<void> delete(String tenantId, String id);
  Future<GoalContribution> contribute(String goalId, double amount);
}

class SupabaseGoalWriteGateway implements GoalWriteGateway {
  SupabaseGoalWriteGateway(this._client);
  final SupabaseClient _client;

  Map<String, dynamic> _body(GoalDraft d) => {
    'title': d.title.trim(),
    'category': d.category,
    'target_amount': d.target.amount.toDouble(),
    'currency': d.target.currency,
    'target_date': d.targetDate == null ? null : _isoDate(d.targetDate!),
  };

  @override
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    GoalDraft draft,
  ) async {
    try {
      return await _client
          .from('goals')
          .insert({
            'id': _uuid.v4(),
            'tenant_id': tenantId,
            'user_id': ?userId,
            'current_amount': 0,
            ..._body(draft),
          })
          .select()
          .single();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    GoalDraft draft,
  ) async {
    try {
      return await _client
          .from('goals')
          .update(_body(draft))
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .select()
          .single();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    try {
      await _client
          .from('goals')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<GoalContribution> contribute(String goalId, double amount) async {
    try {
      final res = await _client.rpc<dynamic>(
        'goal_contribute',
        params: {'p_goal_id': goalId, 'p_amount': amount},
      );
      return GoalContribution.fromRpc(
        res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{},
      );
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final goalWriteGatewayProvider = Provider<GoalWriteGateway>(
  (ref) => SupabaseGoalWriteGateway(ref.watch(supabaseClientProvider)),
  name: 'goalWriteGateway',
);
