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
}
