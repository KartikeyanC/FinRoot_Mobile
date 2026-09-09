import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/sync/presentation/sync_status_widgets.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:finroot_mobile/features/transactions/presentation/widgets/transaction_tile.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Money _m(String v) => Money(Decimal.parse(v));

TransactionEntity _txn(
  String id, {
  TxnType type = TxnType.expense,
  String amount = '1234.50',
}) => TransactionEntity(
  id: id,
  type: type,
  amount: _m(amount),
  category: 'Food & Dining',
  occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
  description: 'Groceries',
);

Widget _wrap(Widget child) =>
    MaterialApp(theme: AppTheme.light, home: Scaffold(body: Center(child: child)));

void main() {
  group('AmountText — spoken label', () {
    testWidgets('an expense is read as "Expense <amount>", not "minus …"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AmountText.money(_m('1234.50'), type: TxnType.expense)),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Expense ')), findsOneWidget);
    });

    testWidgets('income and transfer name their direction', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              AmountText.money(_m('500'), type: TxnType.income),
              AmountText.money(_m('500'), type: TxnType.transfer),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel(RegExp(r'^Income ')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Transfer ')), findsOneWidget);
    });

    testWidgets('a typeless amount is just the magnitude', (tester) async {
      await tester.pumpWidget(_wrap(AmountText.money(_m('9999'))));
      expect(find.bySemanticsLabel(RegExp(r'^(Income|Expense|Transfer) ')),
          findsNothing);
    });
  });

  testWidgets('TransactionTile is one merged, tappable semantics node', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 360,
          child: TransactionTile(_txn('a'), onTap: () => tapped = true),
        ),
      ),
    );

    // Title, subtitle and the (direction-worded) amount are merged into one node.
    final node = tester.getSemantics(find.byType(TransactionTile));
    expect(node.label, contains('Groceries'));
    expect(node.label, contains('Expense'));

    await tester.tap(find.byType(TransactionTile));
    expect(tapped, isTrue);
  });

  testWidgets('the sync banner is an assertive live region', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWithValue(
            const SyncStatusView(
              tone: SyncTone.problem,
              online: true,
              failedCount: 2,
              pendingCount: 0,
            ),
          ),
        ],
        child: _wrap(const SyncStatusBanner()),
      ),
    );
    await tester.pump();

    final liveRegion = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.liveRegion ?? false),
    );
    expect(liveRegion, findsWidgets);
    expect(find.textContaining("didn't sync"), findsOneWidget);
  });

  testWidgets('the ledger reflows at 2x text scale without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
          ledgerProvider.overrideWith(
            (ref) => Stream.value([
              _txn('a'),
              _txn('b', type: TxnType.income, amount: '87654.00'),
            ]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 2.0,
              maxScaleFactor: 2.0,
              child: const TransactionsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Transactions'), findsOneWidget);
  });
}
