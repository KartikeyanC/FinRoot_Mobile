// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Gw implements SubscriptionsGateway {
  final inserted = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  final deleted = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async => const [];

  @override
  Future<void> setActive(
    String tenantId,
    String id, {
    required bool active,
  }) async {}

  @override
  Future<void> insert(Map<String, dynamic> row) async => inserted.add(row);

  @override
  Future<void> update(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async => updates.add({'id': id, ...patch});

  @override
  Future<void> delete(String tenantId, String id) async => deleted.add(id);
}

ProviderContainer _container(
  _Gw gw, {
  WorkspaceRole role = WorkspaceRole.owner,
}) => ProviderContainer(
  overrides: [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(role),
    isOnlineProvider.overrideWithValue(true),
    subscriptionsGatewayProvider.overrideWithValue(gw),
  ],
);

final _netflix = SubscriptionDraft(
  name: ' Netflix ',
  icon: '📺',
  amount: 649,
  frequency: 'monthly',
  renewal: DateTime(2026, 12, 5),
);

void main() {
  test('rows match what the web writes', () async {
    final gw = _Gw();
    final c = _container(gw);
    addTearDown(c.dispose);
    await c.read(subscriptionEditorProvider).add(_netflix);
    expect(gw.inserted.single, {
      'name': 'Netflix',
      'icon': '📺',
      'amount': 649,
      'frequency': 'monthly',
      'renewal_date': '2026-12-05',
      'tenant_id': 't1',
      'currency': 'INR',
      'status': 'active',
    });

    final s = TrackedSubscription.fromRow({
      'id': 's1',
      'name': 'Netflix',
      'amount': 649,
      'frequency': 'monthly',
      'status': 'active',
    });
    await c.read(subscriptionEditorProvider).edit(s, _netflix);
    // An edit never touches the status: cancel / resume does that.
    expect(gw.updates.single.containsKey('status'), isFalse);
    await c.read(subscriptionEditorProvider).delete(s);
    expect(gw.deleted, ['s1']);
  });

  test('a viewer cannot write', () async {
    final gw = _Gw();
    final c = _container(gw, role: WorkspaceRole.viewer);
    addTearDown(c.dispose);
    await expectLater(
      c.read(subscriptionEditorProvider).add(_netflix),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gw.inserted, isEmpty);
  });

  test('renewal dates roll forward by the billing period', () {
    expect(nextRenewal(DateTime(2026, 1, 31), 'weekly'), DateTime(2026, 2, 7));
    expect(
      nextRenewal(DateTime(2026, 11, 5), 'monthly'),
      DateTime(2026, 12, 5),
    );
    expect(nextRenewal(DateTime(2026, 11, 5), 'annual'), DateTime(2027, 11, 5));
    expect(
      catchUpRenewal(DateTime(2026, 8, 5), 'monthly', DateTime(2026, 11, 23)),
      DateTime(2026, 12, 5),
    );
    expect(
      catchUpRenewal(DateTime(2026, 11, 23), 'monthly', DateTime(2026, 11, 23)),
      DateTime(2026, 11, 23),
    );
  });

  test('a bill on the 31st stays on the 31st after a short month', () {
    final jan31 = DateTime(2027, 1, 31);
    expect(nextRenewal(jan31, 'monthly'), DateTime(2027, 2, 28));
    expect(renewalAfter(jan31, 'monthly', 2), DateTime(2027, 3, 31));
    expect(
      catchUpRenewal(jan31, 'monthly', DateTime(2027, 3, 1)),
      DateTime(2027, 3, 31),
    );
    expect(nextRenewal(DateTime(2028, 2, 29), 'annual'), DateTime(2029, 2, 28));
  });

  test('every N months: cost, label and the next renewal', () {
    final s = TrackedSubscription.fromRow({
      'id': 's1',
      'name': 'Hotstar',
      'amount': 900,
      'frequency': 'monthly',
      'interval_months': 3,
      'renewal_date': '2026-08-10',
      'status': 'active',
    });
    expect(s.intervalMonths, 3);
    expect(s.perMonth, 300);
    expect(s.frequencyLabel, '3 months');
    expect(s.upcomingRenewal(DateTime(2026, 11, 25)), DateTime(2027, 2, 10));

    // Rows written before the column existed read as every month.
    final old = TrackedSubscription.fromRow({
      'id': 's2',
      'name': 'Spotify',
      'amount': 119,
      'frequency': 'monthly',
      'status': 'active',
    });
    expect(old.intervalMonths, 1);
    expect(old.frequencyLabel, 'month');
  });

  test('interval_months is written only when a cycle needs it', () async {
    final gw = _Gw();
    final c = _container(gw);
    addTearDown(c.dispose);
    final editor = c.read(subscriptionEditorProvider);

    await editor.add(_netflix);
    expect(gw.inserted.last.containsKey('interval_months'), isFalse);

    final quarterly = SubscriptionDraft(
      name: 'Hotstar',
      amount: 900,
      frequency: 'monthly',
      intervalMonths: 3,
      renewal: DateTime(2026, 12, 10),
    );
    await editor.add(quarterly);
    expect(gw.inserted.last['interval_months'], 3);

    // Back from every 3 months to monthly: the 1 must be written.
    final s = TrackedSubscription.fromRow({
      'id': 's1',
      'name': 'Hotstar',
      'amount': 900,
      'frequency': 'monthly',
      'interval_months': 3,
      'status': 'active',
    });
    await editor.edit(s, _netflix);
    expect(gw.updates.last['interval_months'], 1);
  });
}
