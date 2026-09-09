import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/tracker_draft.dart';
import '../domain/tracker_spend.dart';

const _uuid = Uuid();

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// Writes — like accounts (M8), trackers write straight to PostgREST under RLS
// (which is `has_menu('trackers')`-gated — a locked menu surfaces as a
// PermissionFailure). No offline queue in V1. Assign / unassign touch one
// label column on `transactions` and move no money (web `useAssignToTracker`).
// ---------------------------------------------------------------------------

abstract interface class TrackerWriteGateway {
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    TrackerDraft draft,
  );
  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    TrackerDraft draft,
  );
  Future<Map<String, dynamic>> setStatus(
    String tenantId,
    String id,
    TrackerStatus status,
  );
  Future<void> softDelete(String tenantId, String id);

  /// Bulk-assign untagged transactions. The `tracker_id IS NULL` guard makes
  /// it replay-safe — a row another device tagged meanwhile is skipped.
  Future<void> assign(String tenantId, String trackerId, List<String> ids);
  Future<void> unassign(String tenantId, String id);
}

class SupabaseTrackerWriteGateway implements TrackerWriteGateway {
  SupabaseTrackerWriteGateway(this._client);
  final SupabaseClient _client;

  Map<String, dynamic> _body(TrackerDraft d) => {
    'name': d.name.trim(),
    'type': d.type,
    'start_date': _isoDate(d.startDate),
    'end_date': d.endDate == null ? null : _isoDate(d.endDate!),
    'budget': d.budget?.amount.toDouble(),
    'description': (d.description?.trim().isEmpty ?? true)
        ? null
        : d.description!.trim(),
  };

  @override
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    TrackerDraft draft,
  ) async {
    try {
      return await _client
          .from('trackers')
          .insert({
            'id': _uuid.v4(),
            'tenant_id': tenantId,
            'user_id': ?userId,
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
    TrackerDraft draft,
  ) async {
    try {
      return await _client
          .from('trackers')
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
  Future<Map<String, dynamic>> setStatus(
    String tenantId,
    String id,
    TrackerStatus status,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      return await _client
          .from('trackers')
          .update({
            'status': status.name,
            'completed_at': status == TrackerStatus.completed ? now : null,
            'archived_at': status == TrackerStatus.archived ? now : null,
          })
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .select()
          .single();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> softDelete(String tenantId, String id) async {
    try {
      await _client
          .from('trackers')
          .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> assign(
    String tenantId,
    String trackerId,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return;
    try {
      await _client
          .from('transactions')
          .update({'tracker_id': trackerId})
          .inFilter('id', ids)
          .eq('tenant_id', tenantId)
          .isFilter('tracker_id', null);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> unassign(String tenantId, String id) async {
    try {
      await _client
          .from('transactions')
          .update({'tracker_id': null})
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final trackerWriteGatewayProvider = Provider<TrackerWriteGateway>(
  (ref) => SupabaseTrackerWriteGateway(ref.watch(supabaseClientProvider)),
  name: 'trackerWriteGateway',
);

// ---------------------------------------------------------------------------
// Spend roll-up — `tracker_spend(p_tenant_id)`.
// ---------------------------------------------------------------------------

abstract interface class TrackerSpendGateway {
  Future<List<TrackerSpendRow>> fetch(String tenantId);
}

class SupabaseTrackerSpendGateway implements TrackerSpendGateway {
  SupabaseTrackerSpendGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<TrackerSpendRow>> fetch(String tenantId) async {
    try {
      final res = await _client.rpc<dynamic>(
        'tracker_spend',
        params: {'p_tenant_id': tenantId},
      );
      final list = res is List ? res : const <dynamic>[];
      return [
        for (final row in list)
          if (row is Map)
            TrackerSpendRow.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final trackerSpendGatewayProvider = Provider<TrackerSpendGateway>(
  (ref) => SupabaseTrackerSpendGateway(ref.watch(supabaseClientProvider)),
  name: 'trackerSpendGateway',
);
