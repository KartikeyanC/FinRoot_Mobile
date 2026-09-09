import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/budget_draft.dart';
import '../domain/budget_spend.dart';

// ---------------------------------------------------------------------------
// Spend roll-up — `budget_spend(p_tenant_id)`.
// ---------------------------------------------------------------------------

abstract interface class BudgetSpendGateway {
  Future<List<BudgetSpendRow>> fetch(String tenantId);
}

class SupabaseBudgetSpendGateway implements BudgetSpendGateway {
  SupabaseBudgetSpendGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<BudgetSpendRow>> fetch(String tenantId) async {
    try {
      final res = await _client.rpc<dynamic>(
        'budget_spend',
        params: {'p_tenant_id': tenantId},
      );
      final list = res is List ? res : const <dynamic>[];
      return [
        for (final row in list)
          if (row is Map)
            BudgetSpendRow.fromJson(Map<String, dynamic>.from(row)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final budgetSpendGatewayProvider = Provider<BudgetSpendGateway>(
  (ref) => SupabaseBudgetSpendGateway(ref.watch(supabaseClientProvider)),
  name: 'budgetSpendGateway',
);

// ---------------------------------------------------------------------------
// Writes — `budget_set_allocation` upserts on (tenant, bucket, period_start),
// so two members setting the same bucket end up with one row (web BUG-040).
// Delete is direct PostgREST. Online-only in V1.
// ---------------------------------------------------------------------------

abstract interface class BudgetWriteGateway {
  Future<Map<String, dynamic>> setAllocation(
    String tenantId,
    BudgetAllocationDraft draft,
  );
  Future<void> delete(String tenantId, String id);
}

class SupabaseBudgetWriteGateway implements BudgetWriteGateway {
  SupabaseBudgetWriteGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> setAllocation(
    String tenantId,
    BudgetAllocationDraft draft,
  ) async {
    try {
      final res = await _client.rpc<dynamic>(
        'budget_set_allocation',
        params: {
          'p_tenant_id': tenantId,
          'p_bucket': draft.bucket,
          'p_allocated': draft.allocated.amount.toDouble(),
          'p_period': draft.period,
          if (draft.periodStart != null)
            'p_period_start': _isoDate(draft.periodStart!),
        },
      );
      return res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> delete(String tenantId, String id) async {
    try {
      await _client
          .from('budgets')
          .delete()
          .eq('id', id)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

final budgetWriteGatewayProvider = Provider<BudgetWriteGateway>(
  (ref) => SupabaseBudgetWriteGateway(ref.watch(supabaseClientProvider)),
  name: 'budgetWriteGateway',
);
