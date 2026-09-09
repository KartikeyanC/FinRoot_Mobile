import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/sync_enums.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/accounts/presentation/accounts_screen.dart';
import 'package:finroot_mobile/features/auth/presentation/auth_screen.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/home/presentation/home_screen.dart';
import 'package:finroot_mobile/features/insights/application/insights_providers.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/more/presentation/more_screen.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/summary/application/summary_providers.dart';
import 'package:finroot_mobile/features/summary/domain/workspace_summary.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/trackers/application/trackers_providers.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:finroot_mobile/features/trackers/presentation/trackers_screen.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// M19 — every primary screen renders without a layout overflow at all three
/// breakpoints, in both orientations, and at 1.3x text scale. Guards against
/// the tablet two-pane / rail / dense-header regressions from M16.

const _sizes = <String, Size>{
  'compact portrait': Size(360, 740),
  'compact landscape': Size(740, 360),
  'medium portrait': Size(700, 1000),
  'medium landscape': Size(1000, 700),
  'expanded portrait': Size(900, 1300),
  'expanded landscape': Size(1320, 900),
};

TransactionEntity _txn(String id, {TxnType type = TxnType.expense}) =>
    TransactionEntity(
      id: id,
      type: type,
      amount: Money(Decimal.parse('12345.67')),
      category: 'Food & Dining',
      occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
      description: 'A fairly long note that should ellipsize, not overflow',
      syncState: id == 'p' ? LocalSyncStatus.pendingCreate : LocalSyncStatus.synced,
    );

const _membership = Membership(
  tenantId: 't1',
  name: 'The Kumar Household Extended Family Trust',
  tenantStatus: 'active',
  role: WorkspaceRole.owner,
);

final _common = [
  currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
  currentTenantIdProvider.overrideWithValue('t1'),
  currentUserProvider.overrideWithValue(null),
  currentUserIdProvider.overrideWithValue('u1'),
  currentMembershipProvider.overrideWithValue(_membership),
  syncStatusProvider.overrideWithValue(SyncStatusView.empty),
  profileProvider.overrideWith(
    (ref) async => const Profile(id: 'u1', displayName: 'Priyadarshini'),
  ),
  recentTransactionsProvider.overrideWith(
    (ref) => Stream.value([_txn('a'), _txn('p'), _txn('b', type: TxnType.income)]),
  ),
  recentActivityCountProvider.overrideWith((ref) => Stream.value(42)),
  ledgerProvider.overrideWith(
    (ref) => Stream.value([_txn('a'), _txn('p'), _txn('b', type: TxnType.income)]),
  ),
  transactionByIdProvider('a').overrideWith((ref) => Stream.value(_txn('a'))),
  // Resolve every menu so nothing reaches the real membership RPC.
  effectiveMenusProvider.overrideWith(
    (ref) async => {for (final m in FeatureMenu.values) m.id},
  ),
  homeInsightsProvider.overrideWithValue(const <Insight>[]),
  insightsProvider.overrideWithValue(const <Insight>[]),
  recurringItemsProvider.overrideWith((ref) async => const <RecurringItem>[]),
  remindersProvider.overrideWith((ref) async => const <Reminder>[]),
  trackersWithSpendProvider.overrideWithValue(
    AsyncValue.data(
      foldTrackerSpend(
        [
          TrackerEntity(
            id: 'trk',
            name: 'Dubai Trip With The Whole Family',
            type: 'Travel',
            startDate: DateTime.utc(2026, 3, 2),
            budget: Money.parse('50000'),
          ),
        ],
        [
          TrackerSpendRow(
            trackerId: 'trk',
            type: 'expense',
            currency: 'INR',
            total: Money.parse('61000').amount,
            count: 12,
          ),
        ],
      ),
    ),
  ),
  trackerByIdProvider('trk').overrideWith(
    (ref) => Stream.value(
      TrackerEntity(
        id: 'trk',
        name: 'Dubai Trip With The Whole Family',
        type: 'Travel',
        startDate: DateTime.utc(2026, 3, 2),
        budget: Money.parse('50000'),
      ),
    ),
  ),
  trackerSpendRowsProvider.overrideWith((ref) async => const <TrackerSpendRow>[]),
  trackerTransactionsProvider(
    'trk',
  ).overrideWith((ref) => Stream.value(const <TransactionEntity>[])),
  workspaceAccountsProvider.overrideWithValue(
    AsyncValue.data([
      AccountEntity(
        id: 'sbi',
        name: 'State Bank of India — Joint Savings',
        type: 'bank',
        openingBalance: Money.parse('1234567.89'),
      ),
    ]),
  ),
  workspaceSummaryProvider.overrideWithValue(
    AsyncValue.data(
      WorkspaceSummary(
        accountDeltas: const [],
        monthIncome: Money.zero(),
        monthExpense: Money.zero(),
        transactionCount: 0,
        fetchedAt: DateTime(2026, 9, 9),
      ),
    ),
  ),
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  Size size, {
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _common,
      child: MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: screen,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));

  // A RenderFlex overflow raises a FlutterError during the frame; leaving it
  // uncaught fails the test with the full "error-causing widget" dump.
}

void main() {
  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Transactions': () => const TransactionsScreen(),
    'Trackers': () => const TrackersScreen(),
    'Accounts': () => const AccountsScreen(),
    'More': () => const MoreScreen(),
    'Auth': () => const AuthScreen(),
    'Quick Add sheet': () =>
        const Scaffold(body: SingleChildScrollView(child: QuickAddSheet())),
  };

  for (final screen in screens.entries) {
    for (final size in _sizes.entries) {
      testWidgets('${screen.key} — ${size.key} — no overflow', (tester) async {
        await _pump(tester, screen.value(), size.value);
      });
    }
    testWidgets('${screen.key} — 1.3x text scale — no overflow', (tester) async {
      await _pump(tester, screen.value(), const Size(390, 780), textScale: 1.3);
    });
  }
}
