import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/investments/application/investment_editor_controller.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/investments/data/investments_gateway.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements InvestmentsGateway {
  final List<String> calls = [];
  List<InvestmentRecord> records = [];

  @override
  Future<List<InvestmentRecord>> list(String t) async => records;

  @override
  Future<void> create(String t, String? u, InvestmentDraft d) async {
    calls.add('create:${d.asset}:${d.invested.amount}/${d.current.amount}');
  }

  @override
  Future<void> update(String t, String id, InvestmentDraft d) async =>
      calls.add('update:$id');

  @override
  Future<void> delete(String t, String id) async => calls.add('delete:$id');
}

ProviderContainer _container(
  _FakeGateway gateway, {
  WorkspaceRole role = WorkspaceRole.owner,
  bool online = true,
  MenuStatus menu = MenuStatus.available,
}) {
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      currentUserIdProvider.overrideWithValue('u1'),
      currentRoleProvider.overrideWithValue(role),
      isOnlineProvider.overrideWithValue(online),
      investmentsGatewayProvider.overrideWithValue(gateway),
      menuStatusProvider(FeatureMenu.investments).overrideWithValue(menu),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  final draft = InvestmentDraft(
    asset: 'mutual_funds',
    name: 'Nifty 50',
    invested: Money.parse('50000'),
    current: Money.parse('61000'),
  );

  test('create sends a normalized draft', () async {
    final g = _FakeGateway();
    await _container(g).read(investmentEditorControllerProvider).create(draft);
    expect(g.calls.single, 'create:mutual_funds:50000/61000');
  });

  test('a locked investments menu refuses the write', () async {
    final g = _FakeGateway();
    await expectLater(
      _container(g, menu: MenuStatus.locked)
          .read(investmentEditorControllerProvider)
          .create(draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(g.calls, isEmpty);
  });

  test('offline / viewer are refused', () async {
    await expectLater(
      _container(_FakeGateway(), online: false)
          .read(investmentEditorControllerProvider)
          .create(draft),
      throwsA(isA<NetworkFailure>()),
    );
    await expectLater(
      _container(_FakeGateway(), role: WorkspaceRole.viewer)
          .read(investmentEditorControllerProvider)
          .create(draft),
      throwsA(isA<PermissionFailure>()),
    );
  });

  test('portfolioSummary sums invested / current and gain', () async {
    final g = _FakeGateway()
      ..records = [
        const InvestmentRecord(
          id: 'a',
          asset: 'stocks',
          currency: 'INR',
          fields: {'invested': '10000', 'current': '14000', '_mobile': '1'},
          derived: {},
        ),
        const InvestmentRecord(
          id: 'b',
          asset: 'gold',
          currency: 'INR',
          fields: {'invested': '20000', 'current': '19000', '_mobile': '1'},
          derived: {},
        ),
      ];
    final c = _container(g);
    await c.read(investmentsProvider.future);
    final s = c.read(portfolioSummaryProvider);
    expect(s.invested.formatShort(), Money.parse('30000').formatShort());
    expect(s.current.formatShort(), Money.parse('33000').formatShort());
    expect(s.gain.amount.toString(), '3000');
  });
}
