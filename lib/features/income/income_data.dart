import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error/error_mapper.dart';
import '../../core/error/failure.dart';
import '../../core/money/money.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../../domain/constants.dart';
import '../menus/application/menu_providers.dart';
import '../recurring/application/recurring_editor_controller.dart';
import '../recurring/domain/recurring_item.dart';
import '../workspace/application/workspace_providers.dart';
import 'domain/income_stream.dart';

abstract interface class IncomeGateway {
  Future<List<Map<String, dynamic>>> fetch(String tenantId);
  Future<void> insert(Map<String, dynamic> row);
  Future<void> update(String tenantId, String id, Map<String, dynamic> patch);
  Future<void> delete(String tenantId, String id);
}

class SupabaseIncomeGateway implements IncomeGateway {
  SupabaseIncomeGateway(this._client);
  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) => _guard(() async {
    final rows = await _client
        .from('income_streams')
        .select()
        .eq('tenant_id', tenantId)
        .order('display_order', ascending: true);
    return [for (final r in rows) Map<String, dynamic>.from(r)];
  });

  @override
  Future<void> insert(Map<String, dynamic> row) =>
      _guard(() => _client.from('income_streams').insert(row));

  @override
  Future<void> update(String tenantId, String id, Map<String, dynamic> patch) =>
      _guard(
        () => _client
            .from('income_streams')
            .update(patch)
            .eq('id', id)
            .eq('tenant_id', tenantId),
      );

  @override
  Future<void> delete(String tenantId, String id) => _guard(
    () => _client
        .from('income_streams')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId),
  );
}

final incomeGatewayProvider = Provider<IncomeGateway>(
  (ref) => SupabaseIncomeGateway(ref.watch(supabaseClientProvider)),
  name: 'incomeGateway',
);

/// Every stream of the workspace, shown or hidden, cached for offline.
final incomeStreamsProvider = FutureProvider<List<IncomeStream>>((ref) async {
  final rows = await watchCachedRows(
    ref,
    'income_streams',
    ref.watch(incomeGatewayProvider).fetch,
  );
  return [for (final r in rows) IncomeStream.fromRow(r)]
    ..sort((a, b) => a.order.compareTo(b.order));
}, name: 'incomeStreams');

/// Add, edit, hide, reorder and delete income streams (the web's
/// `useIncomeStreams`). Online only; owners and admins only (RLS).
class IncomeEditor {
  IncomeEditor(this._ref);
  final Ref _ref;

  IncomeGateway get _gw => _ref.read(incomeGatewayProvider);

  String _check() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.income)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Income isn\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }

  /// Adds a stream at the end of the list. With [recurring] set, also adds
  /// the matching recurring income (category, first date), as the web's Add
  /// income does, so it can be marked received each time.
  Future<void> add(
    IncomeStreamDraft d, {
    required List<IncomeStream> existing,
    ({String category, DateTime nextDue})? recurring,
  }) async {
    final tenantId = _check();
    final last = existing.fold<int>(0, (m, s) => s.order > m ? s.order : m);
    await _gw.insert({
      ...d.toRow(),
      'tenant_id': tenantId,
      'is_visible': true,
      'display_order': last + 1,
    });
    _ref.invalidate(incomeStreamsProvider);
    if (recurring != null) {
      await _ref
          .read(recurringEditorControllerProvider)
          .create(
            RecurringDraft(
              type: RecurringType.income,
              name: d.name.trim().isEmpty ? recurring.category : d.name.trim(),
              category: recurring.category,
              subtype: d.type,
              amount: Money(Decimal.parse(d.amount.toString()), d.currency),
              frequency: switch (d.frequency) {
                'weekly' => RecurringFrequency.weekly,
                'one-time' => RecurringFrequency.oneTime,
                _ => RecurringFrequency.monthly,
              },
              nextDueDate: recurring.nextDue,
              icon: d.icon,
              notes: d.notes.trim().isEmpty ? null : d.notes.trim(),
              fxRate: d.rate,
            ),
          );
    }
  }

  Future<void> edit(IncomeStream s, IncomeStreamDraft d) async {
    final tenantId = _check();
    await _gw.update(tenantId, s.id, d.toRow());
    _ref.invalidate(incomeStreamsProvider);
  }

  Future<void> setVisible(IncomeStream s, {required bool visible}) async {
    final tenantId = _check();
    await _gw.update(tenantId, s.id, {'is_visible': visible});
    _ref.invalidate(incomeStreamsProvider);
  }

  /// Saves new positions (`reorderedPositions`).
  Future<void> reorder(Map<String, int> positions) async {
    if (positions.isEmpty) return;
    final tenantId = _check();
    for (final e in positions.entries) {
      await _gw.update(tenantId, e.key, {'display_order': e.value});
    }
    _ref.invalidate(incomeStreamsProvider);
  }

  Future<void> delete(IncomeStream s) async {
    final tenantId = _check();
    await _gw.delete(tenantId, s.id);
    _ref.invalidate(incomeStreamsProvider);
  }
}

final incomeEditorProvider = Provider<IncomeEditor>(
  (ref) => IncomeEditor(ref),
  name: 'incomeEditor',
);
