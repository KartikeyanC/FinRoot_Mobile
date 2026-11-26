import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/domain/ledger_range.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:finroot_mobile/features/transactions/presentation/widgets/ledger_filters.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _txn(String id, String note) => TransactionEntity(
  id: id,
  type: TxnType.expense,
  amount: Money.parse('200.00'),
  category: 'Food',
  occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
  description: note,
);

late ProviderContainer _container;

Widget _host() {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      ledgerProvider.overrideWith(
        (ref) => Stream.value([_txn('a', 'Groceries')]),
      ),
      ledgerCategoriesProvider.overrideWith(
        (ref) => Stream.value(const ['Food', 'Fuel']),
      ),
    ],
    child: Builder(
      builder: (context) {
        _container = ProviderScope.containerOf(context);
        return MaterialApp(
          theme: AppTheme.light,
          home: const TransactionsScreen(),
        );
      },
    ),
  );
}

void main() {
  testWidgets('picking a date preset shows a removable chip', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.text('Any date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last month'));
    await tester.pumpAndSettle();

    final range = _container.read(ledgerFilterProvider).range;
    expect(range?.preset, LedgerRangePreset.lastMonth);
    expect(find.byKey(const ValueKey('ledger-range-chip')), findsOneWidget);

    await tester.tap(find.byTooltip('Remove date filter'));
    await tester.pumpAndSettle();
    expect(_container.read(ledgerFilterProvider).range, isNull);
    expect(find.byKey(const ValueKey('ledger-range-chip')), findsNothing);
  });

  testWidgets('categories can be picked and Clear resets them', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.text('Any category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fuel'));
    await tester.tap(find.text('Food').last);
    await tester.pump();
    await tester.tap(find.text('Show 2 categories'));
    await tester.pumpAndSettle();

    expect(_container.read(ledgerFilterProvider).categories, {'Food', 'Fuel'});
    expect(find.text('2 categories'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ledger-category-chip-Fuel')),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(_container.read(ledgerFilterProvider).categories, isEmpty);
    expect(find.text('Any category'), findsOneWidget);
  });

  testWidgets('a range older than the cache says so in the list', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text(LedgerCacheNotice.message), findsNothing);

    _container
        .read(ledgerFilterProvider.notifier)
        .setRange(LedgerRange.custom(DateTime(2020), DateTime.now()));
    await tester.pump();
    await tester.pump();

    expect(find.text(LedgerCacheNotice.message), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
  });
}
