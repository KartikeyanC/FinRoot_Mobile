import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';

const _uuid = Uuid();

/// Investments live in the `investments` table (RLS + `has_menu('investments')`
/// gated). They are **not** in the offline cache (M1 audit §"what is cached") —
/// this reads and writes live PostgREST, like the web
/// (`src/lib/investmentsStore.ts`).
abstract interface class InvestmentsGateway {
  Future<List<InvestmentRecord>> list(String tenantId);
  Future<void> create(String tenantId, String? userId, InvestmentDraft draft);
  Future<void> update(String tenantId, String id, InvestmentDraft draft);
  Future<void> delete(String tenantId, String id);
}

class SupabaseInvestmentsGateway implements InvestmentsGateway {
  SupabaseInvestmentsGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<InvestmentRecord>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('investments')
          .select()
          .eq('tenant_id', tenantId)
          .order('saved_at', ascending: false);
      return [
        for (final r in rows as List) _fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> create(
    String tenantId,
    String? userId,
    InvestmentDraft draft,
  ) async {
    try {
      await _client.from('investments').insert({
        'id': _uuid.v4(),
        'tenant_id': tenantId,
        'user_id': ?userId,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        ..._body(draft),
      });
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> update(
    String tenantId,
    String id,
    InvestmentDraft draft,
  ) async {
    try {
      await _client
          .from('investments')
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
          .from('investments')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  Map<String, dynamic> _body(InvestmentDraft d) => {
    'asset': d.asset,
    'currency': d.currency,
    'goal': d.goal,
    'fields': buildHoldingFields(
      base: d.baseFields,
      asset: d.asset,
      name: d.name,
      invested: d.invested.amount.toString(),
      current: d.current.amount.toString(),
      ticker: d.ticker,
      quantity: d.quantity,
    ),
    'derived': <String, dynamic>{},
  };

  InvestmentRecord _fromRow(Map<String, dynamic> r) => InvestmentRecord(
    id: r['id'] as String,
    asset: (r['asset'] as String?) ?? 'stocks',
    currency: (r['currency'] as String?) ?? 'INR',
    goal: r['goal'] as String?,
    fields: r['fields'] is Map
        ? Map<String, dynamic>.from(r['fields'] as Map)
        : <String, dynamic>{},
    derived: r['derived'] is Map
        ? Map<String, dynamic>.from(r['derived'] as Map)
        : <String, dynamic>{},
    savedAt: DateTime.tryParse((r['saved_at'] as String?) ?? ''),
  );
}

final investmentsGatewayProvider = Provider<InvestmentsGateway>(
  (ref) => SupabaseInvestmentsGateway(ref.watch(supabaseClientProvider)),
  name: 'investmentsGateway',
);
