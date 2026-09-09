import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_editor_controller.dart';
import 'package:finroot_mobile/features/reminders/data/reminders_gateway.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements RemindersGateway {
  final List<String> calls = [];

  @override
  Future<List<Reminder>> list(String t) async => const [];

  @override
  Future<void> create(String t, ReminderDraft d) async =>
      calls.add('create:${d.title}:${d.context.wire}');

  @override
  Future<void> update(String t, Reminder e, ReminderDraft d) async =>
      calls.add('update:${e.id}');

  @override
  Future<void> setStatus(String t, String id, String status) async =>
      calls.add('status:$id:$status');

  @override
  Future<void> delete(String t, String id) async => calls.add('delete:$id');
}

ProviderContainer _container(
  _FakeGateway g, {
  WorkspaceRole role = WorkspaceRole.owner,
  bool online = true,
  MenuStatus menu = MenuStatus.available,
}) {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentRoleProvider.overrideWithValue(role),
      isOnlineProvider.overrideWithValue(online),
      remindersGatewayProvider.overrideWithValue(g),
      menuStatusProvider(FeatureMenu.reminders).overrideWithValue(menu),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final draft = ReminderDraft(
    title: 'Rent',
    context: ReminderContext.fixedDue,
    dueDate: DateTime(2026, 10, 2),
  );

  test('create sends the reminder', () async {
    final g = _FakeGateway();
    await _container(g).read(remindersEditorControllerProvider).create(draft);
    expect(g.calls.single, 'create:Rent:fixed_due');
  });

  test('complete / reopen set the status', () async {
    final g = _FakeGateway();
    final c = _container(g);
    await c.read(remindersEditorControllerProvider).complete('a');
    await c.read(remindersEditorControllerProvider).reopen('a');
    expect(g.calls, ['status:a:completed', 'status:a:scheduled']);
  });

  test('locked reminders menu refuses the write', () async {
    final g = _FakeGateway();
    await expectLater(
      _container(g, menu: MenuStatus.locked)
          .read(remindersEditorControllerProvider)
          .create(draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(g.calls, isEmpty);
  });

  test('offline and viewer are refused', () async {
    await expectLater(
      _container(_FakeGateway(), online: false)
          .read(remindersEditorControllerProvider)
          .create(draft),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      _container(_FakeGateway(), role: WorkspaceRole.viewer)
          .read(remindersEditorControllerProvider)
          .delete('a'),
      throwsA(isA<PermissionFailure>()),
    );
  });
}
