import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/net_worth_gateway.dart';
import '../domain/net_worth.dart';
import 'net_worth_providers.dart';

/// Add / edit / delete a manual net-worth line. Online-only; menu-gated
/// (`net-worth` — ADR-0002).
class NetWorthEditorController {
  NetWorthEditorController(this._ref);

  final Ref _ref;

  Future<void> add(NetWorthDraft draft) =>
      _write((t) => _ref.read(netWorthGatewayProvider).addEntry(t, draft));

  Future<void> update(String id, NetWorthDraft draft) => _write(
    (t) => _ref.read(netWorthGatewayProvider).updateEntry(t, id, draft),
  );

  Future<void> delete(String id) =>
      _write((t) => _ref.read(netWorthGatewayProvider).deleteEntry(t, id));

  Future<void> _write(Future<void> Function(String tenantId) action) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.netWorth)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Net worth isn\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    await action(tenantId);
    _ref.invalidate(netWorthEntriesProvider);
  }
}

final netWorthEditorControllerProvider = Provider<NetWorthEditorController>(
  (ref) => NetWorthEditorController(ref),
  name: 'netWorthEditorController',
);
