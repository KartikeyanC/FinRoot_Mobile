import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/recurring_gateway.dart';
import '../data/recurring_reminders_gateway.dart';
import '../domain/recurring_item.dart';
import '../domain/reminder_setting.dart';
import 'recurring_providers.dart';

/// Create / edit / delete recurring templates, mark one generated, and manage
/// the per-item reminder setting. Online-only.
///
/// Not menu-gated: the web reaches recurring items from the Income / Expenses
/// pages, whose menus are effectively always-on — there is no `recurring`
/// feature menu. Session + role + connectivity still gate every write.
class RecurringEditorController {
  RecurringEditorController(this._ref);

  final Ref _ref;

  /// Create a template and, if [reminder] is enabled, set its bell in the same
  /// flow. A failed bell does not roll back the item.
  Future<void> create(RecurringDraft draft, {ReminderSetting? reminder}) =>
      _write((t) async {
        final userId = _ref.read(currentUserIdProvider);
        if (userId == null) throw AuthFailure.sessionExpired();
        final id =
            await _ref.read(recurringGatewayProvider).create(t, userId, draft);
        if (reminder != null && reminder.enabled) {
          await _ref
              .read(recurringRemindersGatewayProvider)
              .save(t, id, reminder);
        }
      });

  Future<void> update(String id, RecurringDraft draft) => _write(
    (t) => _ref.read(recurringGatewayProvider).update(t, id, draft),
  );

  Future<void> delete(String id) =>
      _write((t) => _ref.read(recurringGatewayProvider).delete(t, id));

  /// Post the due transaction + advance the item (server RPC), then pull so the
  /// new transaction lands in the local cache.
  Future<void> markGenerated(String id) => _write((_) async {
    await _ref.read(recurringGatewayProvider).markGenerated(id);
    await _ref.read(syncEngineProvider.notifier).syncNow(force: true);
  }, invalidateReminders: false);

  Future<void> saveReminder(String itemId, ReminderSetting setting) => _write(
    (t) => _ref
        .read(recurringRemindersGatewayProvider)
        .save(t, itemId, setting),
    invalidateItems: false,
  );

  Future<void> removeReminder(String itemId) => _write(
    (t) => _ref.read(recurringRemindersGatewayProvider).remove(t, itemId),
    invalidateItems: false,
  );

  Future<void> _write(
    Future<void> Function(String tenantId) action, {
    bool invalidateItems = true,
    bool invalidateReminders = true,
  }) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    await action(tenantId);
    if (invalidateItems) _ref.invalidate(recurringItemsProvider);
    if (invalidateReminders) _ref.invalidate(recurringRemindersProvider);
  }
}

final recurringEditorControllerProvider = Provider<RecurringEditorController>(
  (ref) => RecurringEditorController(ref),
  name: 'recurringEditorController',
);
