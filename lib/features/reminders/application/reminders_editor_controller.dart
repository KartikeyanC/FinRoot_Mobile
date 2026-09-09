import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/reminders_gateway.dart';
import '../domain/reminder.dart';
import 'reminders_providers.dart';

/// Create / edit / complete / delete a standalone reminder. Online-only;
/// menu-gated (`reminders` — ADR-0002, web `menuContract`).
class RemindersEditorController {
  RemindersEditorController(this._ref);

  final Ref _ref;

  Future<void> create(ReminderDraft draft) =>
      _write((t) => _ref.read(remindersGatewayProvider).create(t, draft));

  Future<void> update(Reminder existing, ReminderDraft draft) => _write(
    (t) => _ref.read(remindersGatewayProvider).update(t, existing, draft),
  );

  Future<void> complete(String id) => _write(
    (t) => _ref.read(remindersGatewayProvider).setStatus(t, id, 'completed'),
  );

  Future<void> reopen(String id) => _write(
    (t) => _ref.read(remindersGatewayProvider).setStatus(t, id, 'scheduled'),
  );

  Future<void> delete(String id) =>
      _write((t) => _ref.read(remindersGatewayProvider).delete(t, id));

  Future<void> _write(Future<void> Function(String tenantId) action) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.reminders)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Reminders aren\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    await action(tenantId);
    _ref.invalidate(remindersProvider);
  }
}

final remindersEditorControllerProvider = Provider<RemindersEditorController>(
  (ref) => RemindersEditorController(ref),
  name: 'remindersEditorController',
);
