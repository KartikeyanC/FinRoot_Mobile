import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/reminder.dart';

/// `public.reminders` — tenant-scoped, RLS `is_tenant_member(..., 'admin')` for
/// writes. Not cached — live PostgREST (`src/lib/remindersStore.ts`).
abstract interface class RemindersGateway {
  Future<List<Reminder>> list(String tenantId);
  Future<void> create(String tenantId, ReminderDraft draft);
  Future<void> update(String tenantId, Reminder existing, ReminderDraft draft);
  Future<void> setStatus(String tenantId, String id, String status);
  Future<void> delete(String tenantId, String id);
}

class SupabaseRemindersGateway implements RemindersGateway {
  SupabaseRemindersGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Reminder>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('reminders')
          .select()
          .eq('tenant_id', tenantId)
          .order('due_date', ascending: true);
      return [
        for (final r in rows as List)
          Reminder.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> create(String tenantId, ReminderDraft draft) async {
    try {
      await _client.from('reminders').insert({
        'tenant_id': tenantId,
        'status': 'scheduled',
        'source': 'manual',
        ..._body(draft),
      });
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> update(
    String tenantId,
    Reminder existing,
    ReminderDraft draft,
  ) async {
    try {
      await _client
          .from('reminders')
          .update(_body(draft))
          .eq('id', existing.id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> setStatus(String tenantId, String id, String status) async {
    try {
      await _client
          .from('reminders')
          .update({'status': status})
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
          .from('reminders')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Map<String, dynamic> _body(ReminderDraft d) => {
    'title': d.title.trim(),
    'context': d.context.wire,
    'due_date': _isoDate(d.dueDate),
    'amount': d.amount?.amount.toDouble(),
    'currency': d.amount?.currency,
    'notes': (d.notes ?? '').trim().isEmpty ? null : d.notes!.trim(),
    'frequency':
        d.context == ReminderContext.fixedDue ? d.frequency?.wire : null,
  };

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final remindersGatewayProvider = Provider<RemindersGateway>(
  (ref) => SupabaseRemindersGateway(ref.watch(supabaseClientProvider)),
  name: 'remindersGateway',
);
