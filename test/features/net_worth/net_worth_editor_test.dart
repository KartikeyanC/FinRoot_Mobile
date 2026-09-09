import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/net_worth/application/net_worth_editor_controller.dart';
import 'package:finroot_mobile/features/net_worth/data/net_worth_gateway.dart';
import 'package:finroot_mobile/features/net_worth/domain/net_worth.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements NetWorthGateway {
  final List<String> calls = [];

  @override
  Future<List<NetWorthEntry>> listEntries(String t) async => const [];

  @override
  Future<void> addEntry(String t, NetWorthDraft d) async =>
      calls.add('add:${d.kind}:${d.group}:${d.amount.amount}');

  @override
  Future<void> updateEntry(String t, String id, NetWorthDraft d) async =>
      calls.add('update:$id');

  @override
  Future<void> deleteEntry(String t, String id) async => calls.add('del:$id');

  @override
  Future<List<NetWorthPoint>> history(String t) async => const [];

  @override
  Future<void> recordSnapshot(
    String t, {
    required double assets,
    required double liabilities,
  }) async => calls.add('snap:$assets:$liabilities');
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
      netWorthGatewayProvider.overrideWithValue(g),
      menuStatusProvider(FeatureMenu.netWorth).overrideWithValue(menu),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final draft = NetWorthDraft(
    kind: 'liability',
    group: 'home_loan',
    name: 'Flat EMI',
    amount: Money.parse('3500000'),
  );

  test('add sends the entry', () async {
    final g = _FakeGateway();
    await _container(g).read(netWorthEditorControllerProvider).add(draft);
    expect(g.calls.single, 'add:liability:home_loan:3500000');
  });

  test('locked net-worth menu refuses the write', () async {
    final g = _FakeGateway();
    await expectLater(
      _container(g, menu: MenuStatus.locked)
          .read(netWorthEditorControllerProvider)
          .add(draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(g.calls, isEmpty);
  });

  test('offline / viewer refused', () async {
    await expectLater(
      _container(_FakeGateway(), online: false)
          .read(netWorthEditorControllerProvider)
          .add(draft),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      _container(_FakeGateway(), role: WorkspaceRole.viewer)
          .read(netWorthEditorControllerProvider)
          .add(draft),
      throwsA(isA<PermissionFailure>()),
    );
  });
}
