import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _txn(String id, {String? note, String category = 'Food & Dining'}) =>
    TransactionEntity(
      id: id,
      type: TxnType.expense,
      amount: Money.parse('200.00'),
      category: category,
      occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
      description: note,
    );

Widget _host(List<TransactionEntity> ledger) {
  return ProviderScope(
    overrides: [
      ledgerProvider.overrideWith((ref) => Stream.value(ledger)),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const TransactionsScreen()),
  );
}

void main() {
  testWidgets('renders the ledger with type filter chips', (tester) async {
    await tester.pumpWidget(_host([_txn('a', note: 'Groceries')]));
    await tester.pump();

    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
  });

  testWidgets('empty ledger shows the first-run prompt', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pump();

    expect(find.text('No transactions yet'), findsOneWidget);
  });
}
