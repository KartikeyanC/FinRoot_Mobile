// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/debts/debts_screen.dart';
import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/insurance/insurance_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

class _DebtsGw implements DebtsGateway {
  final debts = <Map<String, dynamic>>[];
  final reminders = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> fetch(String t) async => const [];
  @override
  Future<void> setInstallments(
    String t,
    String d,
    List<Map<String, dynamic>> i,
  ) async {}
  @override
  Future<void> insertDebt(Map<String, dynamic> row) async => debts.add(row);
  @override
  Future<void> updateDebt(String t, String d, Map<String, dynamic> p) async {}
  @override
  Future<void> deleteDebt(String t, String d) async {}
  @override
  Future<void> insertReminders(List<Map<String, dynamic>> rows) async =>
      reminders.addAll(rows);
  @override
  Future<void> deleteOpenReminders(String t, String d) async {}
  @override
  Future<void> deleteReminders(String t, List<String> ids) async {}
  @override
  Future<void> updateReminder(
    String t,
    String id,
    Map<String, dynamic> p,
  ) async {}
}

class _SubsGw implements SubscriptionsGateway {
  final inserted = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> fetch(String t) async => const [];
  @override
  Future<void> setActive(String t, String id, {required bool active}) async {}
  @override
  Future<void> insert(Map<String, dynamic> row) async => inserted.add(row);
  @override
  Future<void> update(String t, String id, Map<String, dynamic> p) async {}
  @override
  Future<void> delete(String t, String id) async {}
}

class _InsGw implements InsuranceGateway {
  final inserted = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> fetch(String t) async => const [];
  @override
  Future<void> insert(Map<String, dynamic> row) async => inserted.add(row);
  @override
  Future<void> update(String t, String id, Map<String, dynamic> p) async {}
  @override
  Future<void> delete(String t, String id) async {}
  @override
  Future<void> upload(String path, List<int> bytes, String mime) async {}
  @override
  Future<void> removeObject(String path) async {}
  @override
  Future<String?> signedUrl(String path) async => null;
}

Widget _host(Widget screen, List<Override> extra) => ProviderScope(
  overrides: [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
    isOnlineProvider.overrideWithValue(true),
    effectiveMenusProvider.overrideWith(
      (ref) async => {for (final m in FeatureMenu.values) m.id},
    ),
    debtsProvider.overrideWith((ref) async => const <Debt>[]),
    trackedSubscriptionsProvider.overrideWith(
      (ref) async => const <TrackedSubscription>[],
    ),
    insuranceProvider.overrideWith((ref) async => const <InsurancePolicy>[]),
    ...extra,
  ],
  child: MaterialApp(theme: AppTheme.light, home: screen),
);

Future<void> _open(WidgetTester tester, String key) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add a debt from the empty Debts page', (tester) async {
    final gw = _DebtsGw();
    await tester.pumpWidget(
      _host(const DebtsScreen(), [debtsGatewayProvider.overrideWithValue(gw)]),
    );
    await _open(tester, 'debt-add-empty');

    // Empty form: nothing is saved, the fields say what is missing.
    await _save(tester, 'Add debt');
    expect(find.text('Add the lender or source'), findsOneWidget);
    expect(gw.debts, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('debt-lender')), 'HDFC');
    await tester.enterText(find.byKey(const ValueKey('debt-total')), '36000');
    await tester.tap(find.text('6 mo'));
    await tester.pump();
    expect(find.byKey(const ValueKey('debt-preview')), findsOneWidget);
    expect(find.textContaining('6,000'), findsOneWidget); // a month
    await _save(tester, 'Add debt');

    expect(gw.debts.single['lender'], 'HDFC');
    expect(gw.debts.single['duration'], 6);
    expect(gw.reminders, hasLength(6));
    expect(find.textContaining('6 EMIs scheduled'), findsOneWidget);
  });

  testWidgets('add a subscription from the empty page', (tester) async {
    final gw = _SubsGw();
    await tester.pumpWidget(
      _host(const SubscriptionsScreen(), [
        subscriptionsGatewayProvider.overrideWithValue(gw),
      ]),
    );
    await _open(tester, 'sub-add-empty');
    await tester.enterText(find.byKey(const ValueKey('sub-name')), 'Spotify');
    await tester.enterText(find.byKey(const ValueKey('sub-amount')), '119');
    await tester.tap(find.text('🎵'));
    await _save(tester, 'Add subscription');
    expect(gw.inserted.single['name'], 'Spotify');
    expect(gw.inserted.single['icon'], '🎵');
    expect(gw.inserted.single['amount'], 119);
    expect(gw.inserted.single['frequency'], 'monthly');
  });

  testWidgets('add a policy from the empty Insurance page', (tester) async {
    final gw = _InsGw();
    await tester.pumpWidget(
      _host(const InsuranceScreen(), [
        insuranceGatewayProvider.overrideWithValue(gw),
      ]),
    );
    await _open(tester, 'policy-add-empty');
    await _save(tester, 'Add policy');
    expect(find.text('Add the policy name'), findsOneWidget);
    expect(gw.inserted, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('policy-name')), 'Family');
    await tester.tap(find.text('🚗 Vehicle'));
    await tester.enterText(
      find.byKey(const ValueKey('policy-provider')),
      'HDFC Ergo',
    );
    await tester.enterText(find.byKey(const ValueKey('policy-number')), 'V-1');
    await tester.enterText(
      find.byKey(const ValueKey('policy-premium')),
      '9000',
    );
    await _save(tester, 'Add policy');
    final row = gw.inserted.single;
    expect(row['policy_name'], 'Family');
    expect(row['category'], 'vehicle');
    expect(row['premium'], 9000);
    expect(row['payment_frequency'], 'Annual');
  });
}
