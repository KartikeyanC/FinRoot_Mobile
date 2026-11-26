import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/split/data/split_dues_gateway.dart';
import 'package:finroot_mobile/features/split/domain/split_dues.dart';
import 'package:finroot_mobile/features/trips/data/trips_gateway.dart';
import 'package:finroot_mobile/features/trips/domain/trip.dart';
import 'package:finroot_mobile/features/trips/presentation/trip_detail_screen.dart';
import 'package:finroot_mobile/features/trips/presentation/trip_list_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../split/split_fakes.dart';

class FakeTripsGateway implements TripsGateway {
  FakeTripsGateway(this.rows);
  final List<Map<String, dynamic>> rows;
  final added = <(String, Map<String, dynamic>)>[];

  @override
  Future<List<Trip>> list(String tenantId) async => [
    for (final r in rows) Trip.fromRow(r),
  ];

  @override
  Future<void> addExpense(
    String tenantId,
    String tripId,
    TripExpense expense,
  ) async {
    added.add((tripId, expense.toJson()));
    final row = rows.firstWhere((r) => r['id'] == tripId);
    row['expenses'] = [expense.toJson(), ...(row['expenses'] as List)];
  }
}

Map<String, dynamic> _goaRow() => {
  'id': 'trip1',
  'name': 'Goa',
  'kind': 'friends',
  'start_date': '2026-11-20',
  'days': 4,
  'companions': ['Asha', 'Ravi'],
  'allocation': {'_cash': 5000, 'acc1': 10000},
  'expenses': [
    {
      'id': 'exp_1',
      'amount': 900,
      'accountId': '_cash',
      'category': 'Stay',
      'at': '2026-11-21T10:00:00Z',
      'splitWith': ['Ravi'],
      'paidBy': 'Asha',
    },
    {
      'id': 'exp_2',
      'amount': 300,
      'accountId': 'acc1',
      'category': 'Food',
      'note': 'Dinner',
      'at': '2026-11-21T20:00:00Z',
      'splitWith': ['Asha', 'Ravi'],
      'paidBy': 'you',
      'futureKey': 42,
    },
  ],
  'status': 'active',
  'archived_at': null,
  'created_at': '2026-11-19T10:00:00Z',
};

void main() {
  group('trip domain', () {
    test('reads the web row and keeps unknown expense keys', () {
      final t = Trip.fromRow(_goaRow());
      expect(t.companions, ['Asha', 'Ravi']);
      expect(t.expenses.first.payer, 'Asha');
      expect(t.expenses.last.payer, kMe);
      expect(t.expenses.last.toJson()['futureKey'], 42);
      final tot = TripTotals.of(t);
      expect(tot.allocated, 15000);
      expect(tot.spent, 1200);
      expect(tot.remainingByAccount['_cash'], 4100);
    });

    test('settle-up uses the web minimal-transfers result', () {
      final t = Trip.fromRow(_goaRow());
      // Asha +500, Ravi -400, you -100 (web tripPayer test).
      expect(tripTransfers(t), const [
        Transfer(from: 'Ravi', to: 'Asha', amount: 400, currency: 'INR'),
        Transfer(from: kMe, to: 'Asha', amount: 100, currency: 'INR'),
      ]);
    });

    test('solo trips never settle', () {
      final row = _goaRow()..['kind'] = 'solo';
      expect(tripTransfers(Trip.fromRow(row)), isEmpty);
    });

    test('new item: paidBy "you" by default, a paying companion shares', () {
      final trip = Trip.fromRow(_goaRow());
      final now = DateTime.utc(2026, 11, 22, 9);
      final mine = newTripExpense(
        trip: trip,
        amount: 100,
        accountId: '_cash',
        category: 'Food',
        splitWith: ['Asha'],
        paidBy: kTripPayerYou,
        now: now,
      ).toJson();
      expect(mine['paidBy'], 'you');
      expect(mine['splitWith'], ['Asha']);
      expect(mine['id'], 'exp_${now.millisecondsSinceEpoch}');
      expect(mine.containsKey('note'), isFalse);

      final hers = newTripExpense(
        trip: trip,
        amount: 100,
        accountId: '_cash',
        category: 'Food',
        splitWith: [],
        paidBy: 'Ravi',
        note: ' Taxi ',
        now: now,
      ).toJson();
      expect(hers['paidBy'], 'Ravi');
      expect(hers['splitWith'], ['Ravi']);
      expect(hers['note'], 'Taxi');

      final solo = Trip.fromRow(_goaRow()..['kind'] = 'solo');
      final s = newTripExpense(
        trip: solo,
        amount: 50,
        accountId: '_cash',
        category: 'Food',
        splitWith: [],
        paidBy: kTripPayerYou,
        now: now,
      ).toJson();
      expect(s.containsKey('paidBy'), isFalse);
      expect(s.containsKey('splitWith'), isFalse);
    });
  });

  group('screens', () {
    late FakeTripsGateway trips;
    late FakeSplitDuesGateway dues;

    setUp(() {
      trips = FakeTripsGateway([_goaRow()]);
      dues = FakeSplitDuesGateway();
    });

    Widget host(Widget home, {WorkspaceRole role = WorkspaceRole.owner}) =>
        ProviderScope(
          overrides: [
            currentTenantIdProvider.overrideWithValue('t1'),
            currentRoleProvider.overrideWithValue(role),
            isOnlineProvider.overrideWithValue(true),
            menuStatusProvider(FeatureMenu.trips)
                .overrideWithValue(MenuStatus.available),
            workspaceAccountsProvider.overrideWith(
              (ref) => Stream.value(const [
                AccountEntity(id: 'acc1', name: 'HDFC', type: 'bank'),
              ]),
            ),
            tripsGatewayProvider.overrideWithValue(trips),
            splitDuesGatewayProvider.overrideWithValue(dues),
          ],
          child: MaterialApp(theme: AppTheme.light, home: home),
        );

    testWidgets('list shows trips with budget vs spent', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripListScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Goa'), findsOneWidget);
      expect(find.textContaining('Spent ₹1,200'), findsOneWidget);
    });

    testWidgets('detail: companions, expenses, settle-up, record dues', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();

      expect(find.text('Asha'), findsWidgets);
      expect(
        find.text('Transfers between companions are shown, not recorded.'),
        findsOneWidget,
      );
      expect(find.text('Settle up'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.textContaining('Paid by Asha'), findsOneWidget);

      await tester.tap(find.text('Mark settled'));
      await tester.pumpAndSettle();
      final d = dues.inserted.single;
      expect(d.person, 'Asha');
      expect(d.direction, DueDirection.iOwe);
      expect(d.amount, 100);
      expect(d.source, DueSource.trip);
      expect(d.sourceId, 'trip1');
      expect(d.settled, isTrue);
    });

    testWidgets('detail: missing split_dues shows the message', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      dues.missing = true;
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('run the database update'), findsOneWidget);
      expect(find.text('Mark settled'), findsNothing);
    });

    testWidgets('detail: add an expense paid by a companion', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('trip-expense-amount')),
        '200',
      );
      await tester.tap(find.byKey(const Key('trip-expense-paid-by')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ravi').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Log expense'));
      await tester.tap(find.text('Log expense'));
      await tester.pumpAndSettle();

      final (id, item) = trips.added.single;
      expect(id, 'trip1');
      expect(item['amount'], 200.0);
      expect(item['paidBy'], 'Ravi');
      expect(item['splitWith'], ['Ravi']);
    });

    testWidgets('viewer cannot add or record', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          const TripDetailScreen(tripId: 'trip1'),
          role: WorkspaceRole.viewer,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Expense'), findsNothing);
      expect(find.text('Mark settled'), findsNothing);
    });
  });
}
