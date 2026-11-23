import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/calendar/calendar_screen.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/debts/debts_screen.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/insurance/insurance.dart';
import 'package:finroot_mobile/features/insurance/insurance_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/search/presentation/search_screen.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions_screen.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

final _debtRow = {
  'id': 'd1',
  'lender': 'HDFC car loan',
  'category': 'Vehicle',
  'currency': 'INR',
  'total_amount': '30000',
  'monthly': 10000,
  'duration': 3,
  'installments': [
    {'month': 1, 'dueDate': '2026-08-05', 'amount': 10000, 'status': 'paid', 'reminderId': 'r1'},
    {'month': 2, 'dueDate': '2026-09-05', 'amount': 10000, 'status': 'pending', 'reminderId': 'r2'},
    {'month': 3, 'dueDate': '2026-10-05', 'amount': 10000, 'status': 'pending'},
  ],
};

TransactionEntity _txn(String id, TxnType type, DateTime at, {String category = 'Food & Dining'}) =>
    TransactionEntity(
      id: id,
      type: type,
      amount: Money(Decimal.parse('100')),
      category: category,
      occurredAt: at,
    );

Future<void> _pump(WidgetTester tester, Widget screen, List<Override> overrides) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [currentRoleProvider.overrideWithValue(WorkspaceRole.owner), ...overrides],
    child: MaterialApp(theme: AppTheme.light, home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('debts', () {
    final debt = Debt.fromRow(_debtRow);

    test('read the web row and do the web debtSummary maths', () {
      expect(debt.total, 30000);
      expect(debt.paidAmount, 10000);
      expect(debt.remaining, 20000);
      expect(debt.paidCount, 1);
      expect(debt.remainingCount, 2);
      expect(debt.nextDue?.month, 2);
      expect(debt.isClosed, isFalse);
    });

    test('mark paid changes only that EMI and keeps unknown fields', () {
      final next = installmentsPaying(debt, 2, DateTime.utc(2026, 9, 6));
      expect(next[1]['status'], 'paid');
      expect(next[1]['paidAt'], '2026-09-06T00:00:00.000Z');
      expect(next[1]['reminderId'], 'r2', reason: 'the web links reminders here');
      expect(next[2]['status'], 'pending');
    });

    testWidgets('screen shows what is owed and the next EMI', (tester) async {
      await _pump(tester, const DebtsScreen(), [
        debtsProvider.overrideWith((ref) async => [debt]),
      ]);
      expect(find.text('HDFC car loan'), findsOneWidget);
      expect(find.textContaining('Next: EMI 2'), findsOneWidget);
      expect(find.text('Mark paid'), findsOneWidget);
    });
  });

  group('subscriptions', () {
    test('monthly cost matches the web monthlyEquivalent', () {
      TrackedSubscription s(String f, num a) =>
          TrackedSubscription.fromRow({'id': f, 'name': f, 'amount': a, 'frequency': f, 'status': 'active'});
      expect(s('monthly', 199).perMonth, 199);
      expect(s('weekly', 120).perMonth, 520);
      expect(s('annual', 1200).perMonth, 100);
      expect(
        TrackedSubscription.fromRow({'id': 'x', 'amount': 1, 'frequency': 'monthly', 'status': 'cancel'}).active,
        isFalse,
      );
    });

    testWidgets('screen splits active from cancelled', (tester) async {
      await _pump(tester, const SubscriptionsScreen(), [
        trackedSubscriptionsProvider.overrideWith((ref) async => [
              TrackedSubscription.fromRow(
                  {'id': 'a', 'name': 'Netflix', 'icon': '🎬', 'amount': 649, 'frequency': 'monthly', 'status': 'active'}),
              TrackedSubscription.fromRow(
                  {'id': 'b', 'name': 'Gym', 'amount': 12000, 'frequency': 'annual', 'status': 'cancel'}),
            ]),
      ]);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.textContaining('a month'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });
  });

  testWidgets('insurance lists policies when the menu is on', (tester) async {
    await _pump(tester, const InsuranceScreen(), [
      menuStatusProvider(FeatureMenu.insurance).overrideWithValue(MenuStatus.available),
      insuranceProvider.overrideWith((ref) async => [
            InsurancePolicy.fromRow({
              'id': 'p1',
              'policy_name': 'Family floater',
              'category': 'Health',
              'premium': '18500',
              'sum_insured': 1000000,
              'provider': 'Star Health',
            }),
          ]),
    ]);
    expect(find.text('Family floater'), findsOneWidget);
    expect(find.text('Health · Star Health'), findsOneWidget);
  });

  testWidgets('insurance is locked when the workspace has it off', (tester) async {
    await _pump(tester, const InsuranceScreen(), [
      menuStatusProvider(FeatureMenu.insurance).overrideWithValue(MenuStatus.locked),
    ]);
    expect(find.text('Family floater'), findsNothing);
  });

  group('calendar', () {
    test('groups transactions by day of month', () {
      final g = byDay([
        _txn('a', TxnType.expense, DateTime(2026, 10, 3, 9)),
        _txn('b', TxnType.income, DateTime(2026, 10, 3, 18)),
        _txn('c', TxnType.expense, DateTime(2026, 10, 20)),
      ]);
      expect(g.keys.toSet(), {3, 20});
      expect(g[3]!.length, 2);
    });

    testWidgets('tapping a day lists its transactions', (tester) async {
      final month = DateTime(2026, 10);
      await _pump(tester, CalendarScreen(today: DateTime(2026, 10, 29)), [
        calendarMonthProvider(month).overrideWith((ref) => Stream.value([
              _txn('a', TxnType.expense, DateTime(2026, 10, 3, 9), category: 'Travel'),
            ])),
      ]);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Nothing on this day.'), findsOneWidget, reason: 'the 29th is empty');
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing on this day.'), findsNothing);
      expect(find.textContaining('Travel'), findsWidgets);
    });
  });

  testWidgets('search finds accounts and transactions', (tester) async {
    await _pump(tester, const SearchScreen(), [
      currentTenantIdProvider.overrideWithValue('t1'),
      workspaceAccountsProvider.overrideWith((ref) => Stream.value(const [
            AccountEntity(id: 'a1', name: 'HDFC Savings', type: 'bank'),
            AccountEntity(id: 'a2', name: 'Cash', type: 'cash'),
          ])),
      goalsProvider.overrideWith((ref) => Stream.value(const [])),
      searchTrackersProvider.overrideWith((ref) => Stream.value(const [])),
      searchTransactionsProvider('hdfc').overrideWith((ref) => Stream.value([
            _txn('t', TxnType.expense, DateTime(2026, 10, 3), category: 'HDFC card fee'),
          ])),
    ]);
    expect(find.textContaining('Type to search'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hdfc');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('HDFC Savings'), findsOneWidget);
    expect(find.text('Cash'), findsNothing);
    // The section heading is a title plus a count pill (one account, one
    // transaction match), not a single "Transactions · 1" string.
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('HDFC card fee'), findsOneWidget);
    expect(matchesQuery('HDFC Savings', ' hdfc '), isTrue);
  });
}
