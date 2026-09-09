import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/net_worth.dart';

/// `net_worth_entries` (manual asset/liability lines) and `net_worth_snapshots`
/// (the trend). Not cached — live PostgREST, like the web.
abstract interface class NetWorthGateway {
  Future<List<NetWorthEntry>> listEntries(String tenantId);
  Future<void> addEntry(String tenantId, NetWorthDraft draft);
  Future<void> updateEntry(String tenantId, String id, NetWorthDraft draft);
  Future<void> deleteEntry(String tenantId, String id);

  Future<List<NetWorthPoint>> history(String tenantId);

  /// Upsert today's figures on `(tenant_id, captured_on)` so history
  /// accumulates just by opening the screen. Silent on failure.
  Future<void> recordSnapshot(
    String tenantId, {
    required double assets,
    required double liabilities,
  });
}

class SupabaseNetWorthGateway implements NetWorthGateway {
  SupabaseNetWorthGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<NetWorthEntry>> listEntries(String tenantId) async {
    try {
      final rows = await _client
          .from('net_worth_entries')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: true);
      return [
        for (final r in rows as List)
          NetWorthEntry.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Map<String, dynamic> _body(NetWorthDraft d) => {
    'kind': d.kind,
    'grp': d.group,
    'name': d.name.trim(),
    'amount': d.amount.amount.toDouble(),
  };

  @override
  Future<void> addEntry(String tenantId, NetWorthDraft draft) async {
    try {
      await _client
          .from('net_worth_entries')
          .insert({'tenant_id': tenantId, ..._body(draft)});
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> updateEntry(
    String tenantId,
    String id,
    NetWorthDraft draft,
  ) async {
    try {
      await _client
          .from('net_worth_entries')
          .update(_body(draft))
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> deleteEntry(String tenantId, String id) async {
    try {
      await _client
          .from('net_worth_entries')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<List<NetWorthPoint>> history(String tenantId) async {
    try {
      final rows = await _client
          .from('net_worth_snapshots')
          .select('captured_on, assets, liabilities, net_worth')
          .eq('tenant_id', tenantId)
          .order('captured_on', ascending: true);
      return [
        for (final r in rows as List)
          NetWorthPoint.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> recordSnapshot(
    String tenantId, {
    required double assets,
    required double liabilities,
  }) async {
    if (assets == 0 && liabilities == 0) return;
    final now = DateTime.now();
    final capturedOn =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      await _client.from('net_worth_snapshots').upsert({
        'tenant_id': tenantId,
        'captured_on': capturedOn,
        'assets': assets,
        'liabilities': liabilities,
        'net_worth': assets - liabilities,
      }, onConflict: 'tenant_id,captured_on');
    } catch (_) {
      // Recording history must never interrupt the screen.
    }
  }
}

final netWorthGatewayProvider = Provider<NetWorthGateway>(
  (ref) => SupabaseNetWorthGateway(ref.watch(supabaseClientProvider)),
  name: 'netWorthGateway',
);
