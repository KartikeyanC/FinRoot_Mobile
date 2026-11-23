// ignore_for_file: avoid_redundant_argument_values
import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/income/domain/income_stream.dart';
import 'package:finroot_mobile/features/income/income_data.dart';
import 'package:finroot_mobile/features/income/income_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/recurring/data/recurring_gateway.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IncomeGw implements IncomeGateway {
  final inserted = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  @override
  Future<List<Map<String, dynamic>>> fetch(String tenantId) async => const [];
  @override
  Future<void> insert(Map<String, dynamic> row) async => inserted.add(row);
  @override
  Future<void> update(
    String tenantId,
    String id,
    Map<String, dynamic> patch,
  ) async => updates.add({'id': id, ...patch});
  @override
  Future<void> delete(String tenantId, String id) async {}
}

class _RecurringGw implements RecurringGateway {
  final drafts = <RecurringDraft>[];
  @override
  Future<List<RecurringItem>> list(String tenantId) async => const [];
  @override
  Future<String> create(String t, String u, RecurringDraft d) async {
    drafts.add(d);
    return 'r1';
  }

  @override
  Future<void> update(String t, String id, RecurringDraft d) async {}
  @override
  Future<void> delete(String t, String id) async {}
  @override
  Future<void> markGenerated(String id) async {}
}

final _streams = [
  IncomeStream.fromRow({
    'id': 's1',
    'name': 'Acme salary',
    'type': 'active',
    'icon': 'Briefcase',
    'amount': 5000,
    'currency': 'USD',
    'exchange_rate_to_inr': 84,
    'is_visible': true,
    'display_order': 1,
  }),
  IncomeStream.fromRow({
    'id': 's2',
    'name': 'Flat rent',
    'type': 'passive',
    'icon': 'Home',
    'amount': 25000,
    'currency': 'INR',
    'exchange_rate_to_inr': 1,
    'is_visible': true,
    'display_order': 2,
  }),
  IncomeStream.fromRow({
    'id': 's3',
    'name': 'Old gig',
    'type': 'passive',
    'icon': 'Mic',
    'amount': 900,
    'currency': 'INR',
    'exchange_rate_to_inr': 1,
    'is_visible': false,
    'display_order': 3,
  }),
];

Future<void> _pump(
  WidgetTester tester, {
  required List<IncomeStream> streams,
  required _IncomeGw gw,
  _RecurringGw? rec,
  bool hidden = false,
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'finroot.income.hidden': hidden});
  final prefs = await SharedPreferences.getInstance();
  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
    currentTenantIdProvider.overrideWithValue('t1'),
    currentUserIdProvider.overrideWithValue('u1'),
    currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
    isOnlineProvider.overrideWithValue(true),
    effectiveMenusProvider.overrideWith(
      (ref) async => {for (final m in FeatureMenu.values) m.id},
    ),
    incomeStreamsProvider.overrideWith((ref) async => streams),
    incomeGatewayProvider.overrideWithValue(gw),
    recurringGatewayProvider.overrideWithValue(rec ?? _RecurringGw()),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.light, home: const IncomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add the first stream from the empty page', (tester) async {
    final gw = _IncomeGw();
    final rec = _RecurringGw();
    await _pump(tester, streams: const [], gw: gw, rec: rec);
    expect(find.text('No income streams'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('income-add-empty')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Passive'));
    await tester.pump();
    await tester.tap(find.text('Rental'));
    await tester.enterText(
      find.byKey(const ValueKey('income-amount')),
      '25000',
    );
    await tester.pump();
    expect(find.text('₹25,000 a month'), findsOneWidget);
    // The sheet's button (the empty page has one with the same words).
    await tester.tap(find.widgetWithText(FilledButton, 'Add income').last);
    await tester.pumpAndSettle();

    final row = gw.inserted.single;
    expect(row['name'], 'Rental'); // the category, when no name is typed
    expect(row['type'], 'passive');
    expect(row['amount'], 25000);
    expect(row['display_order'], 1);
    expect(rec.drafts.single.category, 'Rental');
  });

  testWidgets('the page totals shown streams in rupees, a row per stream', (
    tester,
  ) async {
    await _pump(tester, streams: _streams, gw: _IncomeGw());
    // 5,000 USD at 84 = 4,20,000 + 25,000 rent; the hidden gig is left out.
    expect(find.text('₹4.45L'), findsOneWidget);
    expect(find.text('Acme salary'), findsOneWidget);
    expect(find.text('Flat rent'), findsOneWidget);
    expect(find.text('Old gig'), findsNothing);
    expect(find.text(r'$5,000 at ₹84'), findsOneWidget);
    expect(find.text('1 hidden'), findsOneWidget);
  });

  testWidgets('show a hidden stream again from the sheet', (tester) async {
    final gw = _IncomeGw();
    await _pump(tester, streams: _streams, gw: gw);
    await tester.tap(find.text('1 hidden'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('income-visible-s3')));
    await tester.pumpAndSettle();
    expect(gw.updates.single, {'id': 's3', 'is_visible': true});
  });

  testWidgets('hidden income masks every figure on the page', (tester) async {
    await _pump(tester, streams: _streams, gw: _IncomeGw(), hidden: true);
    expect(find.text('₹4.45L'), findsNothing);
    expect(find.text(r'$5,000 at ₹84'), findsNothing);
    expect(find.text('₹ ••••'), findsWidgets);
    expect(find.text('Acme salary'), findsOneWidget); // names stay readable
  });
}
