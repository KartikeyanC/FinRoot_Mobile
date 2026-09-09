import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_editor_controller.dart';
import 'package:finroot_mobile/features/recurring/data/recurring_gateway.dart';
import 'package:finroot_mobile/features/recurring/data/recurring_reminders_gateway.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:finroot_mobile/features/sync/application/sync_engine.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements RecurringGateway {
  final List<String> calls = [];

  @override
  Future<List<RecurringItem>> list(String t) async => const [];

  @override
  Future<String> create(String t, String userId, RecurringDraft d) async {
    calls.add('create:${d.type.wire}:${d.name}:${d.amount.amount}');
    return 'new-id';
  }

  @override
  Future<void> update(String t, String id, RecurringDraft d) async =>
      calls.add('update:$id');

  @override
  Future<void> delete(String t, String id) async => calls.add('delete:$id');

  @override
  Future<void> markGenerated(String id) async => calls.add('mark:$id');
}

class _FakeRemGateway implements RecurringRemindersGateway {
  final List<String> calls = [];

  @override
  Future<Map<String, ReminderSetting>> list(String t) async => const {};

  @override
  Future<void> save(String t, String itemId, ReminderSetting s) async =>
      calls.add('save:$itemId:${s.enabled}:${s.daysBefore}');

  @override
  Future<void> remove(String t, String itemId) async =>
      calls.add('remove:$itemId');
}

class _FakeSyncEngine extends SyncEngine {
  int kicks = 0;
  @override
  SyncSnapshot build() => const SyncSnapshot();
  @override
  Future<void> syncNow({bool full = false, bool force = false}) async =>
      kicks++;
}

ProviderContainer _container(
  _FakeGateway g,
  _FakeRemGateway r, {
  WorkspaceRole role = WorkspaceRole.owner,
  bool online = true,
  String? userId = 'u1',
}) {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentUserIdProvider.overrideWithValue(userId),
      currentRoleProvider.overrideWithValue(role),
      isOnlineProvider.overrideWithValue(online),
      recurringGatewayProvider.overrideWithValue(g),
      recurringRemindersGatewayProvider.overrideWithValue(r),
      syncEngineProvider.overrideWith(_FakeSyncEngine.new),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final draft = RecurringDraft(
    type: RecurringType.expense,
    name: 'Rent',
    category: 'Rent',
    amount: Money.parse('25000'),
    frequency: RecurringFrequency.monthly,
    nextDueDate: DateTime(2026, 10, 2),
  );

  test('create sends the template', () async {
    final g = _FakeGateway();
    await _container(g, _FakeRemGateway())
        .read(recurringEditorControllerProvider)
        .create(draft);
    expect(g.calls.single, 'create:expense:Rent:25000');
  });

  test('create with an enabled reminder sets the bell too', () async {
    final g = _FakeGateway();
    final r = _FakeRemGateway();
    await _container(g, r).read(recurringEditorControllerProvider).create(
          draft,
          reminder: const ReminderSetting(enabled: true, daysBefore: 5),
        );
    expect(g.calls.single, startsWith('create:'));
    expect(r.calls.single, 'save:new-id:true:5');
  });

  test('markGenerated calls the RPC and nudges a sync', () async {
    final g = _FakeGateway();
    final c = _container(g, _FakeRemGateway());
    await c.read(recurringEditorControllerProvider).markGenerated('x1');
    expect(g.calls.single, 'mark:x1');
    expect((c.read(syncEngineProvider.notifier) as _FakeSyncEngine).kicks, 1);
  });

  test('offline is refused', () async {
    final g = _FakeGateway();
    await expectLater(
      _container(g, _FakeRemGateway(), online: false)
          .read(recurringEditorControllerProvider)
          .create(draft),
      throwsA(isA<NetworkFailure>()),
    );
    expect(g.calls, isEmpty);
  });

  test('a viewer is refused', () async {
    final g = _FakeGateway();
    await expectLater(
      _container(g, _FakeRemGateway(), role: WorkspaceRole.viewer)
          .read(recurringEditorControllerProvider)
          .delete('x'),
      throwsA(isA<PermissionFailure>()),
    );
    expect(g.calls, isEmpty);
  });

  test('missing user id fails create', () async {
    await expectLater(
      _container(_FakeGateway(), _FakeRemGateway(), userId: null)
          .read(recurringEditorControllerProvider)
          .create(draft),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('saveReminder / removeReminder proxy the gateway', () async {
    final r = _FakeRemGateway();
    final c = _container(_FakeGateway(), r);
    await c.read(recurringEditorControllerProvider).saveReminder(
          'i9',
          const ReminderSetting(enabled: true, daysBefore: 2),
        );
    await c.read(recurringEditorControllerProvider).removeReminder('i9');
    expect(r.calls, ['save:i9:true:2', 'remove:i9']);
  });
}
