import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:finroot_mobile/features/transactions/presentation/widgets/txn_words.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _t(
  String? desc, {
  String? mode,
  TxnType type = TxnType.expense,
}) => TransactionEntity(
  id: '1',
  type: type,
  amount: Money(Decimal.parse('250')),
  category: 'Food & Dining',
  description: desc,
  paymentMode: mode,
  occurredAt: DateTime(2026, 11, 23, 9, 30),
);

void main() {
  test('the title drops the markers the web stores in a note', () {
    expect(
      _t('[HDFC Savings|0b1c-22] Lunch with team').title,
      'Lunch with team',
    );
    expect(_t('⟦SPLIT|owe|Ravi⟧ [ICICI|x] Dinner').title, 'Dinner');
    expect(_t('[HDFC|x]').title, 'Food & Dining');
    expect(_t(null).title, 'Food & Dining');
  });

  test('the second line says what happened in words', () {
    expect(txnFacts(_t('[HDFC Savings|x] Lunch', mode: 'UPI')), [
      'Food & Dining',
      'Paid by UPI',
      'HDFC Savings',
    ]);
    expect(txnFacts(_t('⟦SPLIT|owe|Ravi⟧ Dinner')), [
      'Food & Dining',
      'Ravi owes you',
    ]);
    expect(paidViaLabel('Cash', TxnType.income), 'Received in cash');
    expect(paidViaLabel(null, TxnType.expense), isNull);
  });
}
