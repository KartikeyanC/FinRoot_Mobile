import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/investments_gateway.dart';
import '../domain/investment.dart';
import 'investments_providers.dart';

/// Create / edit / delete an investment holding. Online-only; menu-gated
/// (`investments` — ADR-0002).
class InvestmentEditorController {
  InvestmentEditorController(this._ref);

  final Ref _ref;

  Future<void> create(InvestmentDraft draft) => _write(
    (t) => _ref
        .read(investmentsGatewayProvider)
        .create(t, _ref.read(currentUserIdProvider), draft),
  );

  Future<void> update(String id, InvestmentDraft draft) => _write(
    (t) => _ref.read(investmentsGatewayProvider).update(t, id, draft),
  );

  Future<void> delete(String id) =>
      _write((t) => _ref.read(investmentsGatewayProvider).delete(t, id));

  Future<void> _write(Future<void> Function(String tenantId) action) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.investments)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Investments aren\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    await action(tenantId);
    _ref.invalidate(investmentsProvider);
  }
}

final investmentEditorControllerProvider =
    Provider<InvestmentEditorController>(
      (ref) => InvestmentEditorController(ref),
      name: 'investmentEditorController',
    );
