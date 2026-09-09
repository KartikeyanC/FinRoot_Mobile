import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/sync_enums.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/home/application/home_providers.dart';
import 'package:finroot_mobile/features/home/presentation/home_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/profile/profile_providers.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/trackers/application/trackers_providers.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _txn({
  required String id,
  TxnType type = TxnType.expense,
  String amount = '250.00',
  String category = 'Food & Dining',
  String? description,
  LocalSyncStatus sync = LocalSyncStatus.synced,
}) {
  return TransactionEntity(
    id: id,
    type: type,
    amount: Money(Decimal.parse(amount)),
    category: category,
    occurredAt: DateTime.now().subtract(const Duration(hours: 3)),
    description: description,
    syncState: sync,
  );
}

Widget _host({
  List<TransactionEntity> recent = const [],
  int count = 0,
  List<TrackerEntity> trackers = const [],
  MenuStatus trackerMenu = MenuStatus.available,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      profileProvider.overrideWith(
        (ref) async => const Profile(id: 'u1', displayName: 'Priya Kumar'),
      ),
      currentMembershipProvider.overrideWithValue(
        const Membership(
          tenantId: 't1',
          name: 'Kumar Household',
          tenantStatus: 'active',
          role: WorkspaceRole.owner,
        ),
      ),
      syncStatusProvider.overrideWithValue(SyncStatusView.empty),
      recentTransactionsProvider.overrideWith((ref) => Stream.value(recent)),
      recentActivityCountProvider.overrideWith((ref) => Stream.value(count)),
      trackersWithSpendProvider.overrideWithValue(
        AsyncValue.data(foldTrackerSpend(trackers, null)),
      ),
      menuStatusProvider(
        FeatureMenu.trackers,
      ).overrideWithValue(trackerMenu),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const HomeScreen(),
    ),
  );
}

void main() {
  testWidgets('greets by first name and shows the workspace', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Priya'), findsOneWidget);
    expect(find.text('Kumar Household'), findsOneWidget);
  });

  testWidgets('snapshot shows the recorded count, not a money figure', (
    tester,
  ) async {
    await tester.pumpWidget(_host(count: 7));
    await tester.pump();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('transactions recorded'), findsOneWidget);
    // No accounts in this scope → no money hero, just the nudge.
    expect(find.textContaining('Add accounts to see balances'), findsOneWidget);
  });

  testWidgets('empty recent activity shows a useful prompt, no "See all"', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Nothing recorded yet'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
  });

  testWidgets('recent transactions render with a See all link', (tester) async {
    await tester.pumpWidget(
      _host(
        recent: [
          _txn(id: 'a', description: 'Groceries'),
          _txn(id: 'b', type: TxnType.income, category: 'Salary'),
        ],
        count: 2,
      ),
    );
    await tester.pump();

    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
  });

  testWidgets('a pending transaction is marked on its row', (tester) async {
    await tester.pumpWidget(
      _host(
        recent: [_txn(id: 'a', sync: LocalSyncStatus.pendingCreate)],
        count: 1,
      ),
    );
    await tester.pump();

    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('trackers section is hidden when there are none', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Trackers'), findsNothing);
  });

  testWidgets('trackers section shows active trackers', (tester) async {
    await tester.pumpWidget(
      _host(
        trackers: [
          TrackerEntity(
            id: 'trk',
            name: 'Home Build',
            type: 'Home Construction',
            startDate: DateTime.utc(2026, 3, 2),
            budget: Money(Decimal.parse('500000.00')),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('Trackers'), findsOneWidget);
    expect(find.text('T-Home Build'), findsOneWidget);
  });

  testWidgets('trackers section stays hidden when the menu is locked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        trackers: [
          TrackerEntity(
            id: 'trk',
            name: 'Home Build',
            type: 'Home Construction',
            startDate: DateTime.utc(2026, 3, 2),
          ),
        ],
        trackerMenu: MenuStatus.locked,
      ),
    );
    await tester.pump();

    expect(find.text('Trackers'), findsNothing);
  });
}
