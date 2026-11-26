import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/goal_draft.dart';
import '../domain/goal_history.dart';

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

  /// [note] goes through the `goal_contribute(uuid, numeric, text)` overload;
  /// until that migration is applied the amount still lands via the
  /// two-argument call and the result carries `noteDropped`.
  Future<GoalContribution> contribute(
    String goalId,
    double amount, {
    String? note,
  });

  /// The goal's contribution history, newest first (`goal_contributions`,
  /// shared with the web). [GoalHistory.missing] while the table is absent.
  Future<GoalHistory> history(String tenantId, String goalId, String currency);
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
  Future<GoalContribution> contribute(
    String goalId,
    double amount, {
    String? note,
  }) async {
    final cleaned = cleanGoalNote(note);
    var noteDropped = false;
    try {
      if (cleaned != null) {
        try {
          return _result(
            await _client.rpc<dynamic>(
              'goal_contribute',
              params: {
                'p_goal_id': goalId,
                'p_amount': amount,
                'p_note': cleaned,
              },
            ),
          );
        } on PostgrestException catch (e) {
          if (!isGoalHistoryMissingError(e.code, e.message)) rethrow;
          noteDropped = true; // fall through to the original call
        }
      }
      final result = _result(
        await _client.rpc<dynamic>(
          'goal_contribute',
          params: {'p_goal_id': goalId, 'p_amount': amount},
        ),
      );
      return noteDropped ? result.withNoteDropped() : result;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  static GoalContribution _result(Object? res) => GoalContribution.fromRpc(
    res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{},
  );

  @override
  Future<GoalHistory> history(
    String tenantId,
    String goalId,
    String currency,
  ) async {
    try {
      final rows = await _client
          .from('goal_contributions')
          .select('id, goal_id, amount, note, contributed_at')
          .eq('tenant_id', tenantId)
          .eq('goal_id', goalId)
          .order('contributed_at', ascending: false)
          .limit(200);
      return GoalHistory([
        for (final r in rows)
          GoalContributionEntry.fromRow(r, currency: currency),
      ]);
    } on PostgrestException catch (e, stack) {
      if (isGoalHistoryMissingError(e.code, e.message)) {
        return const GoalHistory.missing();
      }
      throw mapError(e, stack);
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
