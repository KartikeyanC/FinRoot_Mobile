import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Swipe right-to-left = next filter tab, left-to-right = previous.
void main() {
  group('SwipeTabs', () {
    Future<List<int>> pumpTabs(WidgetTester tester, {int start = 1}) async {
      final changes = <int>[];
      var index = start;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SwipeTabs(
                index: index,
                count: 3,
                onChanged: (i) {
                  changes.add(i);
                  setState(() => index = i);
                },
                child: SizedBox.expand(child: Text('tab $index')),
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('right-to-left fling goes to the next tab', (tester) async {
      final changes = await pumpTabs(tester);
      await tester.fling(find.text('tab 1'), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(changes, [2]);
      expect(find.text('tab 2'), findsOneWidget);
    });

    testWidgets('left-to-right fling goes to the previous tab', (tester) async {
      final changes = await pumpTabs(tester);
      await tester.fling(find.text('tab 1'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(changes, [0]);
    });

    testWidgets('stops at the first and last tab', (tester) async {
      final changes = await pumpTabs(tester, start: 0);
      await tester.fling(find.text('tab 0'), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });

    testWidgets('a slow drag does not switch', (tester) async {
      final changes = await pumpTabs(tester);
      await tester.timedDrag(
        find.text('tab 1'),
        const Offset(-120, 0),
        const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
    });
  });

  testWidgets('Transactions: swipe walks All → Income → Expense → back', (
    tester,
  ) async {
    TransactionEntity txn(String id, TxnType type) => TransactionEntity(
      id: id,
      type: type,
      amount: Money(Decimal.parse('100')),
      category: type == TxnType.income ? 'Salary' : 'Food & Dining',
      occurredAt: DateTime.now(),
    );
    final container = ProviderContainer(
      overrides: [
        currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
        ledgerProvider.overrideWith(
          (ref) => Stream.value([
            txn('a', TxnType.expense),
            txn('b', TxnType.income),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    TxnType? type() => container.read(ledgerFilterProvider).type;
    final list = find.byType(SwipeTabs);

    expect(type(), isNull);
    await tester.fling(list, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(type(), TxnType.income);
    await tester.fling(list, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(type(), TxnType.expense);
    await tester.fling(list, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(type(), TxnType.income);
  });
}
