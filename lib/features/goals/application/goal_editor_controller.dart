import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/goal_write_gateway.dart';
import '../data/goals_repository.dart';
import '../domain/goal_draft.dart';

/// Create / edit / delete a goal, and contribute funds. Online-only (V1).
/// `goals` is menu-gated (ADR-0002). Contributions go through the
/// `goal_contribute` RPC, which owns the invariants.
class GoalEditorController {
  GoalEditorController(this._ref);

  final Ref _ref;

  Future<String> create(GoalDraft draft) async {
    final tenantId = _guard();
    final row = await _ref
        .read(goalWriteGatewayProvider)
        .create(tenantId, _ref.read(currentUserIdProvider), draft);
    await _repo.cacheServerRow(row);
    return row['id'] as String;
  }

  Future<void> update(String id, GoalDraft draft) async {
    final tenantId = _guard();
    final row = await _ref
        .read(goalWriteGatewayProvider)
        .update(tenantId, id, draft);
    await _repo.cacheServerRow(row);
  }

  Future<void> delete(String id) async {
    final tenantId = _guard();
    await _ref.read(goalWriteGatewayProvider).delete(tenantId, id);
    await _repo.removeFromCache(id);
  }

  /// Add ([amount] > 0) or take back ([amount] < 0) funds. Returns the RPC
  /// outcome (whether the goal was reached, whether the amount was capped).
  Future<GoalContribution> contribute(String goalId, double amount) async {
    _guard();
    final result = await _ref
        .read(goalWriteGatewayProvider)
        .contribute(goalId, amount);
    await _repo.applyContribution(
      goalId,
      result.currentAmount,
      result.status,
    );
    return result;
  }

  GoalsRepository get _repo => _ref.read(goalsRepositoryProvider);

  String _guard() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.goals)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Goals aren\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }
}

final goalEditorControllerProvider = Provider<GoalEditorController>(
  (ref) => GoalEditorController(ref),
  name: 'goalEditorController',
);
