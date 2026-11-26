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
import 'package:go_router/go_router.dart';

import '../split/split_fakes.dart';

class FakeTripsGateway implements TripsGateway {
  FakeTripsGateway(this.rows);
  final List<Map<String, dynamic>> rows;
  final added = <(String, Map<String, dynamic>)>[];
  final changes = <(String, TripExpenseChange)>[];
  final created = <Map<String, dynamic>>[];
  final currencyChanges = <(String, String, double?)>[];

  @override
  Future<List<Trip>> list(String tenantId) async => [
    for (final r in rows) Trip.fromRow(r),
  ];

  @override
  Future<String> create(String tenantId, NewTrip trip) async {
    final row = {
      ...trip.toRow(tenantId),
      'id': 'trip${rows.length + 1}',
      'created_at': '2026-11-26T10:00:00Z',
    };
    created.add(row);
    rows.insert(0, row);
    return row['id'] as String;
  }

  @override
  Future<void> changeExpense(
    String tenantId,
    String tripId,
    TripExpenseChange change,
  ) async {
    changes.add((tripId, change));
    if (change case AddTripExpense(:final expense)) {
      added.add((tripId, expense.toJson()));
    }
    final row = rows.firstWhere((r) => r['id'] == tripId);
    row['expenses'] = applyTripExpenseChange([
      for (final e in row['expenses'] as List)
        Map<String, dynamic>.from(e as Map),
    ], change);
  }

  @override
  Future<void> setCurrency(
    String tenantId,
    String tripId,
    String currency, {
    double? rate,
  }) async {
    currencyChanges.add((tripId, currency, rate));
    final row = rows.firstWhere((r) => r['id'] == tripId);
    row['currency'] = currency;
    if (rate == null) return;
    row['allocation'] = {
      for (final e in (row['allocation'] as Map).entries)
        e.key: convertTripAmount((e.value as num).toDouble(), rate),
    };
    row['expenses'] = [
      for (final e in row['expenses'] as List)
        {
          ...Map<String, dynamic>.from(e as Map),
          'amount': convertTripAmount((e['amount'] as num).toDouble(), rate),
        },
    ];
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
      // Asha paid the 900 stay: it never left your cash (web tripTotals).
      expect(tot.paidByYou, 300);
      expect(tot.remainingByAccount['_cash'], 5000);
      expect(tot.remainingByAccount['acc1'], 9700);
      expect(tot.remaining, 14700);
      expect(t.currency, 'INR');
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
      // A companion paid: no account of yours is stored (web TripWorkspace).
      expect(hers['accountId'], '');

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

    test(
      'edit keeps id, time and unknown keys; clearing the note clears it',
      () {
        final trip = Trip.fromRow(_goaRow());
        final dinner = trip.expenses.last;
        final edited = editedTripExpense(
          trip: trip,
          original: dinner,
          amount: 450,
          accountId: 'acc1',
          category: 'Food',
          splitWith: ['Asha'],
          paidBy: kTripPayerYou,
          note: '  ',
        ).toJson();
        expect(edited['id'], 'exp_2');
        expect(edited['at'], '2026-11-21T20:00:00Z');
        expect(edited['amount'], 450);
        expect(edited['futureKey'], 42);
        expect(edited.containsKey('note'), isFalse);
        expect(edited['splitWith'], ['Asha']);
      },
    );

    test('applyTripExpenseChange follows the server rules', () {
      final trip = Trip.fromRow(_goaRow());
      final list = [for (final e in trip.expenses) e.toJson()];
      final extra = newTripExpense(
        trip: trip,
        amount: 10,
        accountId: '_cash',
        category: 'Food',
        splitWith: const [],
        paidBy: kTripPayerYou,
        now: DateTime.utc(2026, 11, 23),
      );
      final added = applyTripExpenseChange(list, AddTripExpense(extra));
      expect(added.first['id'], extra.id);
      expect(added, hasLength(3));
      // A retry of the same add changes nothing.
      expect(
        identical(applyTripExpenseChange(added, AddTripExpense(extra)), added),
        isTrue,
      );

      final updated = applyTripExpenseChange(
        list,
        UpdateTripExpense(
          TripExpense.fromJson({...list.first, 'amount': 1000}),
        ),
      );
      expect(updated.first['amount'], 1000);
      expect(updated.last['id'], 'exp_2');

      expect(
        () => applyTripExpenseChange([
          list.last,
        ], UpdateTripExpense(TripExpense.fromJson(list.first))),
        throwsA(isA<StateError>()),
      );
      expect(applyTripExpenseChange(list, const RemoveTripExpense('exp_1')), [
        list.last,
      ]);
      expect(
        applyTripExpenseChange(list, const RemoveTripExpense('nope')),
        list,
      );
    });

    test('rpc calls and migration-missing detection', () {
      final e = Trip.fromRow(_goaRow()).expenses.first;
      expect(tripExpenseRpcCall('t', AddTripExpense(e)).fn, 'trip_expense_add');
      expect(
        tripExpenseRpcCall('t', UpdateTripExpense(e)).fn,
        'trip_expense_update',
      );
      final rm = tripExpenseRpcCall('t', const RemoveTripExpense('exp_1'));
      expect(rm.fn, 'trip_expense_remove');
      expect(rm.params, {'p_trip_id': 't', 'p_expense_id': 'exp_1'});
      expect(isTripExpenseRpcMissing(code: 'PGRST202'), isTrue);
      expect(
        isTripExpenseRpcMissing(code: 'P0002', message: 'This trip is gone'),
        isFalse,
      );
      expect(
        isTripCurrencyMissing(
          code: 'PGRST204',
          message: "Could not find the 'currency' column of 'trips'",
        ),
        isTrue,
      );
      expect(isTripCurrencyMissing(code: '42501', message: 'denied'), isFalse);
    });

    test('a trip in another currency settles in it', () {
      final t = Trip.fromRow(_goaRow()..['currency'] = 'usd');
      expect(t.currency, 'USD');
      expect(tripTransfers(t).map((x) => x.currency).toSet(), {'USD'});
      expect(Trip.fromRow(_goaRow()..['currency'] = 'rupees').currency, 'INR');
    });

    test('a new trip row, and what stops one', () {
      final t = NewTrip(
        name: ' Bali ',
        kind: 'friends',
        days: 0,
        startDate: DateTime(2026, 12, 5),
        companions: ['Riya', 'riya', ' Aman ', 'You'],
        allocation: {'_cash': 500, 'acc1': 0},
        currency: 'USD',
      );
      expect(t.problem, isNull);
      final row = t.toRow('t1');
      expect(row['name'], 'Bali');
      expect(row['start_date'], '2026-12-05');
      expect(row['days'], 1);
      expect(row['companions'], ['Riya', 'Aman']);
      expect(row['allocation'], {'_cash': 500});
      expect(row['currency'], 'USD');
      expect(row['expenses'], isEmpty);

      final inr = NewTrip(
        name: 'Goa',
        kind: 'solo',
        days: 3,
        startDate: DateTime(2026, 12, 5),
        companions: ['Riya'],
        allocation: {'_cash': 100},
      ).toRow('t1');
      // INR isn't sent: it saves before the migration adds the column.
      expect(inr.containsKey('currency'), isFalse);
      expect(inr['companions'], isEmpty);

      expect(
        NewTrip(
          name: ' ',
          kind: 'solo',
          days: 1,
          startDate: DateTime(2026),
          companions: const [],
          allocation: const {'_cash': 1},
        ).problem,
        'Give your trip a name',
      );
      expect(
        NewTrip(
          name: 'X',
          kind: 'solo',
          days: 1,
          startDate: DateTime(2026),
          companions: const [],
          allocation: const {},
        ).problem,
        'Allocate at least one funding source',
      );
      expect(parseCompanions('Riya, , Aman ,'), ['Riya', 'Aman']);
    });
  });

  group('screens', () {
    late FakeTripsGateway trips;
    late FakeSplitDuesGateway dues;

    setUp(() {
      trips = FakeTripsGateway([_goaRow()]);
      dues = FakeSplitDuesGateway();
    });

    Widget host(
      Widget home, {
      WorkspaceRole role = WorkspaceRole.owner,
      bool routed = false,
    }) => ProviderScope(
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
      // routed: the list opens a new trip with context.push, which needs
      // the app's router.
      child: routed
          ? MaterialApp.router(
              theme: AppTheme.light,
              routerConfig: GoRouter(
                initialLocation: TripListScreen.route,
                routes: [
                  GoRoute(path: TripListScreen.route, builder: (_, _) => home),
                  GoRoute(
                    path: '/trips/:id',
                    builder: (_, s) =>
                        TripDetailScreen(tripId: s.pathParameters['id']!),
                  ),
                ],
              ),
            )
          : MaterialApp(theme: AppTheme.light, home: home),
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

    testWidgets('detail: tap an expense to edit it', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      expect(find.text('Edit trip expense'), findsOneWidget);
      final amount = find.byKey(const Key('trip-expense-amount'));
      expect(tester.widget<TextFormField>(amount).controller?.text, '300');
      await tester.enterText(amount, '360');
      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final (id, change) = trips.changes.single;
      expect(id, 'trip1');
      final e = (change as UpdateTripExpense).expense;
      expect(e.id, 'exp_2');
      expect(e.amount, 360);
      expect(e.note, 'Dinner');
      expect(e.toJson()['futureKey'], 42);
      expect(find.textContaining('Expense updated'), findsOneWidget);
    });

    testWidgets('detail: delete an expense after confirming', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('trip-expense-delete')));
      await tester.tap(find.byKey(const Key('trip-expense-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      final (_, change) = trips.changes.single;
      expect((change as RemoveTripExpense).id, 'exp_2');
      expect(find.text('Dinner'), findsNothing);
    });

    testWidgets('viewer cannot open an expense to edit', (tester) async {
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
      await tester.tap(find.text('Dinner'));
      await tester.pumpAndSettle();
      expect(find.text('Edit trip expense'), findsNothing);
    });

    testWidgets('list: plan a new trip on the phone', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripListScreen(), routed: true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New trip'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('new-trip-name')), 'Bali');
      await tester.tap(find.text('Friends trip'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-trip-companions')),
        'Riya, Aman',
      );
      await tester.tap(find.byKey(const Key('new-trip-currency')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('new-trip-fund-acc1')),
          matching: find.byType(TextField),
        ),
        '800',
      );
      await tester.pumpAndSettle();
      expect(find.text(r'$800'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('new-trip-create')));
      await tester.tap(find.byKey(const Key('new-trip-create')));
      await tester.pumpAndSettle();

      final row = trips.created.single;
      expect(row['name'], 'Bali');
      expect(row['kind'], 'friends');
      expect(row['companions'], ['Riya', 'Aman']);
      expect(row['allocation'], {'acc1': 800.0});
      expect(row['currency'], 'USD');
      // It opens the new trip.
      expect(find.text('Nothing logged yet'), findsOneWidget);
    });

    testWidgets('list: a new trip needs money in the pool', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripListScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New trip'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('new-trip-name')), 'Goa');
      await tester.ensureVisible(find.byKey(const Key('new-trip-create')));
      await tester.tap(find.byKey(const Key('new-trip-create')));
      await tester.pumpAndSettle();
      expect(find.text('Allocate at least one funding source'), findsOneWidget);
      expect(trips.created, isEmpty);
    });

    testWidgets('list: viewers get no New trip button', (tester) async {
      await tester.pumpWidget(
        host(const TripListScreen(), role: WorkspaceRole.viewer),
      );
      await tester.pumpAndSettle();
      expect(find.text('New trip'), findsNothing);
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
      // Currency shows, but can't be changed.
      expect(find.text('Tap to change'), findsNothing);
      await tester.tap(find.byKey(const Key('trip-currency')));
      await tester.pumpAndSettle();
      expect(find.text('Change trip currency'), findsNothing);
    });

    Future<void> openCurrency(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(const TripDetailScreen(tripId: 'trip1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('trip-currency')));
      await tester.pumpAndSettle();
      expect(find.text('Change trip currency'), findsOneWidget);
    }

    testWidgets('currency: keep the amounts, only the label changes', (
      tester,
    ) async {
      await openCurrency(tester);
      expect(find.textContaining(r'Budget ₹15,000 → $15,000'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-currency-save')));
      await tester.pumpAndSettle();
      expect(trips.currencyChanges.single, ('trip1', 'USD', null));
      expect(find.text('Trip now in USD'), findsOneWidget);
      // The trip reloads in its new currency.
      expect(find.textContaining(r'$1,200'), findsWidgets);
    });

    testWidgets('currency: convert at the rate typed', (tester) async {
      await openCurrency(tester);
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle();
      final rate = find.byKey(const Key('trip-currency-rate'));
      expect(tester.widget<TextField>(rate).controller!.text, '0.011976');
      await tester.enterText(rate, '0.012');
      await tester.pumpAndSettle();
      expect(find.textContaining(r'Budget ₹15,000 → $180'), findsOneWidget);
      expect(find.textContaining(r'Spent ₹1,200 → $14.4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-currency-save')));
      await tester.pumpAndSettle();
      expect(trips.currencyChanges.single, ('trip1', 'USD', 0.012));
      expect(find.text('Trip converted to USD'), findsOneWidget);
    });

    testWidgets('currency: a bad rate is refused before sending', (
      tester,
    ) async {
      await openCurrency(tester);
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('trip-currency-rate')), '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter a rate more than zero'), findsOneWidget);
      await tester.tap(find.byKey(const Key('trip-currency-save')));
      await tester.pumpAndSettle();
      expect(trips.currencyChanges, isEmpty);
    });
  });

  group('changing the currency', () {
    test('converts to two decimals and suggests a rate', () {
      expect(convertTripAmount(250, 0.011976), 2.99);
      expect(convertTripAmount(99.5, 83.5), 8308.25);
      expect(suggestedTripRate('USD', 'INR'), 83.5);
      expect(suggestedTripRate('INR', 'USD'), 0.011976);
      expect(suggestedTripRate('EUR', 'GBP'), 0.857143);
    });

    test('the server rules, checked before sending', () {
      final trip = Trip.fromRow(_goaRow());
      expect(tripCurrencyChangeProblem(trip, 'USD', null), isNull);
      expect(tripCurrencyChangeProblem(trip, 'USD', 0.012), isNull);
      expect(
        tripCurrencyChangeProblem(trip, 'INR', null),
        contains('already in INR'),
      );
      expect(tripCurrencyChangeProblem(trip, 'usd', null), 'Pick a currency');
      expect(
        tripCurrencyChangeProblem(trip, 'USD', 0),
        'Enter a rate more than zero',
      );
      expect(
        tripCurrencyChangeProblem(trip, 'USD', double.nan),
        'Enter a rate more than zero',
      );
      expect(
        tripCurrencyChangeProblem(trip, 'USD', 1e6),
        contains('too large'),
      );
      // 300 × 0.00001 rounds to 0.00.
      expect(
        tripCurrencyChangeProblem(trip, 'USD', 0.00001),
        contains('round to zero'),
      );
    });

    test('knows when trip_set_currency is not switched on yet', () {
      expect(isTripCurrencyRpcMissing(code: 'PGRST202'), isTrue);
      expect(
        isTripCurrencyRpcMissing(
          message: 'function public.trip_set_currency does not exist',
        ),
        isTrue,
      );
      expect(
        isTripCurrencyRpcMissing(code: '22023', message: 'Pick a currency'),
        isFalse,
      );
    });
  });
}
