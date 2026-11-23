import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/recurring_item.dart';

const _uuid = Uuid();

/// `recurring_items` (RLS: `auth.uid() = user_id`) + the `mark_recurring_generated`
/// RPC. Not cached — live PostgREST, like the web (`src/hooks/useRecurring.ts`).
abstract interface class RecurringGateway {
  Future<List<RecurringItem>> list(String tenantId);

  /// Returns the new row's id (generated client-side).
  Future<String> create(String tenantId, String userId, RecurringDraft draft);
  Future<void> update(String tenantId, String id, RecurringDraft draft);
  Future<void> delete(String tenantId, String id);

  /// Post the due transaction and advance `next_due_date`, atomically and
  /// idempotently, server-side (BUG-104). Returns nothing useful.
  Future<void> markGenerated(String id);
}

class SupabaseRecurringGateway implements RecurringGateway {
  SupabaseRecurringGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<RecurringItem>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('recurring_items')
          .select()
          .eq('tenant_id', tenantId)
          .order('next_due_date', ascending: true);
      return [
        for (final r in rows as List)
          RecurringItem.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<String> create(
    String tenantId,
    String userId,
    RecurringDraft draft,
  ) async {
    final id = _uuid.v4();
    try {
      await _client.from('recurring_items').insert({
        'id': id,
        'tenant_id': tenantId,
        'user_id': userId,
        'is_active': true,
        ..._body(draft),
      });
      return id;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> update(String tenantId, String id, RecurringDraft draft) async {
    try {
      await _client
          .from('recurring_items')
          .update(_body(draft))
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    try {
      await _client
          .from('recurring_items')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> markGenerated(String id) async {
    try {
      await _client.rpc<dynamic>(
        'mark_recurring_generated',
        params: {'p_item_id': id},
      );
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Map<String, dynamic> _body(RecurringDraft d) => {
    'type': d.type.wire,
    'name': d.name.trim(),
    'category': d.category,
    'subtype': d.subtype,
    'amount': d.amount.amount.toDouble(),
    'currency': d.amount.currency,
    'fx_rate': d.fxRate,
    'frequency': d.frequency.wire,
    'next_due_date': _isoDate(d.nextDueDate),
    'icon': d.icon,
    'notes': (d.notes ?? '').trim().isEmpty ? null : d.notes!.trim(),
  };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final recurringGatewayProvider = Provider<RecurringGateway>(
  (ref) => SupabaseRecurringGateway(ref.watch(supabaseClientProvider)),
  name: 'recurringGateway',
);
