import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/reminder_setting.dart';

/// `public.recurring_reminders` — one row per recurring item
/// (`UNIQUE(tenant_id, recurring_item_id)`), the bell setting shown on the
/// item's card. Not cached — live PostgREST
/// (`src/hooks/useRecurringReminders.ts`).
abstract interface class RecurringRemindersGateway {
  Future<Map<String, ReminderSetting>> list(String tenantId);
  Future<void> save(String tenantId, String itemId, ReminderSetting setting);
  Future<void> remove(String tenantId, String itemId);
}

class SupabaseRecurringRemindersGateway implements RecurringRemindersGateway {
  SupabaseRecurringRemindersGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, ReminderSetting>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('recurring_reminders')
          .select('recurring_item_id, enabled, days_before, note')
          .eq('tenant_id', tenantId);
      return {
        for (final r in rows as List)
          (r as Map)['recurring_item_id'] as String:
              ReminderSetting.fromRow(Map<String, dynamic>.from(r)),
      };
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> save(
    String tenantId,
    String itemId,
    ReminderSetting setting,
  ) async {
    try {
      await _client.from('recurring_reminders').upsert(
        {
          'tenant_id': tenantId,
          'recurring_item_id': itemId,
          'enabled': setting.enabled,
          'days_before': setting.daysBefore,
          'note': setting.note.trim().isEmpty ? null : setting.note.trim(),
        },
        onConflict: 'tenant_id,recurring_item_id',
      );
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> remove(String tenantId, String itemId) async {
    try {
      await _client
          .from('recurring_reminders')
          .delete()
          .eq('tenant_id', tenantId)
          .eq('recurring_item_id', itemId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final recurringRemindersGatewayProvider = Provider<RecurringRemindersGateway>(
  (ref) =>
      SupabaseRecurringRemindersGateway(ref.watch(supabaseClientProvider)),
  name: 'recurringRemindersGateway',
);
