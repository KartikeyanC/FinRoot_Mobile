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
import 'package:finroot_mobile/features/budget/application/budget_providers.dart';
import 'package:finroot_mobile/features/budget/domain/budget_spend.dart';
import 'package:finroot_mobile/features/budget/presentation/budget_screen.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/home/presentation/home_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/more/presentation/more_screen.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/quick_add/data/custom_categories.dart';
import 'package:finroot_mobile/features/quick_add/presentation/quick_add_sheet.dart';
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

/// M17 — every primary surface is checked against Flutter's built-in
/// accessibility guidelines: text contrast (WCAG 1.4.3), tap-target size
/// (WCAG 2.5.8 / Material) and every tap target carrying a label (WCAG 4.1.2).

TransactionEntity _txn(
  String id, {
  TxnType type = TxnType.expense,
  String amount = '250.00',
  String category = 'Food & Dining',
  String? note,
  LocalSyncStatus sync = LocalSyncStatus.synced,
}) => TransactionEntity(
  id: id,
  type: type,
  amount: Money(Decimal.parse(amount)),
  category: category,
  occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
  description: note,
  syncState: sync,
);

const _membership = Membership(
  tenantId: 't1',
  name: 'Kumar Household',
  tenantStatus: 'active',
  role: WorkspaceRole.owner,
);

WorkspaceSummary _summary() => WorkspaceSummary(
  accountDeltas: const [],
  monthIncome: Money.zero(),
  monthExpense: Money.zero(),
  transactionCount: 0,
  fetchedAt: DateTime(2026, 9, 9),
);

Future<void> _expectAccessible(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  testWidgets('Auth — sign in (light + dark)', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: theme, home: const AuthScreen()),
        ),
      );
      await tester.pump();
      await _expectAccessible(tester);
    }
  });

  testWidgets('Home feed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          profileProvider.overrideWith(
            (ref) async => const Profile(id: 'u1', displayName: 'Priya Kumar'),
          ),
          currentMembershipProvider.overrideWithValue(_membership),
          syncStatusProvider.overrideWithValue(SyncStatusView.empty),
          recentTransactionsProvider.overrideWith(
            (ref) => Stream.value([_txn('a', note: 'Groceries')]),
          ),
          recentActivityCountProvider.overrideWith((ref) => Stream.value(3)),
          trackersWithSpendProvider.overrideWithValue(
            const AsyncData(<TrackerWithSpend>[]),
          ),
          menuStatusProvider(
            FeatureMenu.trackers,
          ).overrideWithValue(MenuStatus.available),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('Transactions ledger (income / expense / transfer / pending)', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          ledgerProvider.overrideWith(
            (ref) => Stream.value([
              _txn('a', note: 'Groceries'),
              _txn('b', type: TxnType.income, category: 'Salary'),
              _txn('c', type: TxnType.transfer, category: 'Transfer'),
              _txn('d', sync: LocalSyncStatus.pendingCreate),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('Trackers list with a near-limit spend bar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          menuStatusProvider(
            FeatureMenu.trackers,
          ).overrideWithValue(MenuStatus.available),
          trackersWithSpendProvider.overrideWithValue(
            AsyncValue.data(
              foldTrackerSpend(
                [
                  TrackerEntity(
                    id: 'a',
                    name: 'Dubai Trip',
                    type: 'Travel',
                    startDate: DateTime.utc(2026, 3, 2),
                    budget: Money.parse('50000'),
                  ),
                ],
                [
                  TrackerSpendRow(
                    trackerId: 'a',
                    type: 'expense',
                    currency: 'INR',
                    total: Money.parse('47000').amount,
                    count: 9,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const TrackersScreen()),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('Accounts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          workspaceAccountsProvider.overrideWithValue(
            AsyncValue.data([
              AccountEntity(
                id: 'sbi',
                name: 'SBI',
                type: 'bank',
                openingBalance: Money.parse('120000'),
              ),
            ]),
          ),
          workspaceSummaryProvider.overrideWithValue(
            AsyncValue.data(_summary()),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const AccountsScreen()),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('Budget — the 7 jars', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          menuStatusProvider(
            FeatureMenu.budget,
          ).overrideWithValue(MenuStatus.available),
          budgetsForPeriodProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          budgetSpendRowsProvider.overrideWith(
            (ref) async => const <BudgetSpendRow>[],
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const BudgetScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await _expectAccessible(tester);
  });

  testWidgets('Quick Add sheet — expense capture', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          currentTenantIdProvider.overrideWithValue('t1'),
          currentUserIdProvider.overrideWithValue('u1'),
          customExpenseCategoriesProvider.overrideWith(_NoCustomCategories.new),
          workspaceAccountsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: QuickAddSheet()),
        ),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('Transactions ledger with an active search filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          ledgerProvider.overrideWith(
            (ref) => Stream.value([_txn('a', note: 'Groceries')]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'coffee');
    await tester.pump();
    await _expectAccessible(tester);
  });

  testWidgets('More list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          currentTenantIdProvider.overrideWithValue('t1'),
          currentMembershipProvider.overrideWithValue(_membership),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const MoreScreen()),
      ),
    );
    await tester.pump();
    await _expectAccessible(tester);
  });
}

/// No workspace categories, and no Supabase / connectivity plugin to fetch them.
class _NoCustomCategories extends CustomExpenseCategories {
  @override
  Future<List<String>> build() async => const [];
}
