import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/export/domain/csv_export.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _t({
  String id = '1',
  TxnType type = TxnType.expense,
  String amount = '100.5',
  String category = 'Food',
  String? description,
  String? accountId,
  String? to,
  DateTime? at,
}) => TransactionEntity(
  id: id,
  type: type,
  amount: Money(Decimal.parse(amount)),
  category: category,
  occurredAt: at ?? DateTime(2026, 3, 5, 14),
  description: description,
  accountId: accountId,
  transferToAccountId: to,
);

void main() {
  test('csvField quotes commas, quotes and newlines', () {
    expect(csvField('plain'), 'plain');
    expect(csvField('a,b'), '"a,b"');
    expect(csvField('say "hi"'), '"say ""hi"""');
    expect(csvField('l1\nl2'), '"l1\nl2"');
  });

  test('header plus one row per transaction, CRLF terminated', () {
    final csv = transactionsToCsv(
      [_t(description: 'Lunch, with team'), _t(id: '2', type: TxnType.income)],
      
    );
    final lines = csv.split('\r\n');
    expect(lines.first, startsWith('Date,Type,Category'));
    expect(lines[1], '2026-03-05,expense,Food,"Lunch, with team",100.50,INR,,,');
    expect(lines[2], startsWith('2026-03-05,income'));
    expect(lines.last, '');
    expect(lines.length, 4);
  });

  test('resolves account names and neutralises formulas', () {
    final csv = transactionsToCsv(
      [
        _t(
          type: TxnType.transfer,
          description: '=HYPERLINK("x")',
          accountId: 'a',
          to: 'b',
        ),
      ],
      accountNames: const {'a': 'HDFC, Savings', 'b': 'Cash'},
    );
    final row = csv.split('\r\n')[1];
    expect(row, contains('"\'=HYPERLINK(""x"")"'));
    expect(row, endsWith(',"HDFC, Savings",Cash'));
  });

  test('empty list is header only', () {
    expect(transactionsToCsv(const []).split('\r\n').length, 2);
  });

  test('filterByType', () {
    final all = [_t(), _t(id: '2', type: TxnType.income)];
    expect(filterByType(all, null).length, 2);
    expect(filterByType(all, TxnType.income).single.id, '2');
  });
}
