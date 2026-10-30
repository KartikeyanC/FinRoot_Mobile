import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/home/presentation/home_screen.dart';
import 'package:finroot_mobile/features/insights/application/insights_providers.dart';
import 'package:finroot_mobile/features/insights/domain/insight.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/more/presentation/more_screen.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/reminders/presentation/reminders_screen.dart';
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
  recentActivityCountProvider.overrideWith((ref) => Stream.value(42)),
  transactionByIdProvider('a').overrideWith((ref) => Stream.value(_txn('a'))),
  effectiveMenusProvider.overrideWith(
    (ref) async => {for (final m in FeatureMenu.values) m.id},
  ),
  homeInsightsProvider.overrideWithValue(const <Insight>[]),
  insightsProvider.overrideWithValue(const <Insight>[]),
  recurringItemsProvider.overrideWith((ref) async => const <RecurringItem>[]),
  remindersProvider.overrideWith((ref) async => const <Reminder>[]),
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
  debtsProvider.overrideWith((ref) async => const <Debt>[]),
  investmentsProvider.overrideWith((ref) async => const []),
  goalsProvider.overrideWith((ref) => Stream.value(const [])),
];


/// Screen snapshots for design review. Skipped unless SNAPSHOT_DIR is set:
///
///   SNAPSHOT_DIR=C:/tmp/shots flutter test test/tool/snapshots_test.dart
///
/// Renders the primary screens in light and dark at 390x844 with realistic
/// sample data, with Inter and the Material icon font loaded so the PNGs look
/// like the app (flutter test otherwise draws every glyph as a box).
const _flutterRoot = String.fromEnvironment(
  'FLUTTER_ROOT',
  defaultValue: r'F:\flutter',
);

TransactionEntity _t(
  String id,
  TxnType type,
  String amount,
  String category,
  String note,
  int hoursAgo,
) => TransactionEntity(
  id: id,
  type: type,
  amount: Money.parse(amount),
  category: category,
  occurredAt: DateTime.now().subtract(Duration(hours: hoursAgo)),
  description: note,
  syncState: LocalSyncStatus.synced,
);

final _sampleTxns = [
  _t('1', TxnType.expense, '1250', 'Food & Dining', 'Dinner at Saravana Bhavan', 3),
  _t('2', TxnType.income, '85000', 'Salary', 'October salary', 30),
  _t('3', TxnType.expense, '4200', 'Transport', 'Cab to airport', 52),
  _t('4', TxnType.expense, '799', 'Entertainment', 'Netflix', 80),
  _t('5', TxnType.expense, '18500', 'Home', 'T-Home building construction', 120),
  _t('6', TxnType.expense, '640', 'Groceries', 'Weekly vegetables', 150),
];

final _snapshotOverrides = [
  ..._common,
  recentTransactionsProvider.overrideWith((ref) => Stream.value(_sampleTxns)),
  ledgerProvider.overrideWith((ref) => Stream.value(_sampleTxns)),
  workspaceSummaryProvider.overrideWithValue(
    AsyncValue.data(
      WorkspaceSummary(
        accountDeltas: const [],
        monthIncome: Money.parse('85000'),
        monthExpense: Money.parse('42360'),
        transactionCount: 6,
        fetchedAt: DateTime.now(),
        monthlySeries: [
          for (var m = 5; m <= 10; m++)
            MonthPoint(
              month: '2026-${m.toString().padLeft(2, '0')}',
              income: Money.parse('${70000 + m * 2000}'),
              expense: Money.parse('${30000 + m * 1500}'),
            ),
        ],
        categorySpend: [
          CategorySpendPoint(category: 'Home', amount: Money.parse('18500'), count: 1),
          CategorySpendPoint(category: 'Food & Dining', amount: Money.parse('9250'), count: 8),
          CategorySpendPoint(category: 'Transport', amount: Money.parse('6100'), count: 4),
          CategorySpendPoint(category: 'Entertainment', amount: Money.parse('2400'), count: 3),
        ],
        categoryIncome: [
          CategorySpendPoint(category: 'Salary', amount: Money.parse('85000'), count: 1),
        ],
      ),
    ),
  ),
  workspaceAccountsProvider.overrideWithValue(
    AsyncValue.data([
      AccountEntity(id: 'a1', name: 'HDFC Savings', type: 'bank', openingBalance: Money.parse('245000')),
      AccountEntity(id: 'a2', name: 'Cash', type: 'cash', openingBalance: Money.parse('6800')),
      AccountEntity(id: 'a3', name: 'ICICI Credit Card', type: 'credit', openingBalance: Money.parse('-12400')),
    ]),
  ),
  trackersWithSpendProvider.overrideWithValue(
    AsyncValue.data(
      foldTrackerSpend(
        [
          TrackerEntity(
            id: 'trk',
            name: 'T-Home building construction',
            type: 'Home',
            startDate: DateTime.utc(2026, 8, 2),
            budget: Money.parse('500000'),
          ),
          TrackerEntity(
            id: 'trk2',
            name: 'Goa trip',
            type: 'Travel',
            startDate: DateTime.utc(2026, 11, 2),
            budget: Money.parse('60000'),
          ),
        ],
        [
          TrackerSpendRow(trackerId: 'trk', type: 'expense', currency: 'INR', total: Money.parse('185000').amount, count: 9),
          TrackerSpendRow(trackerId: 'trk2', type: 'expense', currency: 'INR', total: Money.parse('61000').amount, count: 12),
        ],
      ),
    ),
  ),
];

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(() async {
      final bytes = await File(
        '$_flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      ).readAsBytes();
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }());
  await icons.load();
}

void main() {
  final dir = Platform.environment['SNAPSHOT_DIR'];
  final screens = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'transactions': () => const TransactionsScreen(),
    'trackers': () => const TrackersScreen(),
    'accounts': () => const AccountsScreen(),
    'more': () => const MoreScreen(),
    'reminders-empty': () => const RemindersScreen(),
    'auth': () => const AuthScreen(),
    'quick-add': () =>
        const Scaffold(body: SingleChildScrollView(child: QuickAddSheet())),
  };

  for (final dark in [false, true]) {
    for (final screen in screens.entries) {
      testWidgets('snapshot ${screen.key} ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await tester.runAsync(_loadFonts);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: _snapshotOverrides,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? AppTheme.dark : AppTheme.light,
                home: screen.value(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('$dir/${screen.key}-${dark ? 'dark' : 'light'}.png');
          await out.create(recursive: true);
          await out.writeAsBytes(bytes!.buffer.asUint8List());
        });
      }, skip: dir == null);
    }
  }
}
