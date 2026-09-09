import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/budget_gateways.dart';
import '../data/budgets_repository.dart';
import '../domain/budget_draft.dart';
import 'budget_providers.dart';

/// Set / clear a bucket's allocation. Online-only (V1). `budget` is a
/// menu-gated feature (ADR-0002) — a locked menu surfaces as a
/// [PermissionFailure] before the request.
class BudgetEditorController {
  BudgetEditorController(this._ref);

  final Ref _ref;

  Future<void> setAllocation(BudgetAllocationDraft draft) async {
    final tenantId = _guard();
    final row = await _ref
        .read(budgetWriteGatewayProvider)
        .setAllocation(tenantId, draft);
    if (row.isNotEmpty) {
      await _ref.read(budgetsRepositoryProvider).cacheServerRow(row);
    }
    _ref.invalidate(budgetSpendRowsProvider);
  }

  Future<void> delete(String id) async {
    final tenantId = _guard();
    await _ref.read(budgetWriteGatewayProvider).delete(tenantId, id);
    await _ref.read(budgetsRepositoryProvider).removeFromCache(id);
    _ref.invalidate(budgetSpendRowsProvider);
  }

  String _guard() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.budget)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Budgets aren\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }
}

final budgetEditorControllerProvider = Provider<BudgetEditorController>(
  (ref) => BudgetEditorController(ref),
  name: 'budgetEditorController',
);
