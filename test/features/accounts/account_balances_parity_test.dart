import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/accounts/domain/account_balances.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the ported balance fold against the FinRoot **web** repo's
/// `src/lib/accountBalances.test.ts` (single source of truth — ADR-0008, M1
/// audit §4). If the web rules change, this fails and
/// `lib/features/accounts/domain/account_balances.dart` must change with it.

Decimal d(String s) => Decimal.parse(s);

BalanceTxn txn({
  required String type,
  required String amount,
  String? accountId = 'cash',
  String? transferToAccountId,
  String? description,
}) => BalanceTxn(
  type: type,
  amount: d(amount),
  accountId: accountId,
  transferToAccountId: transferToAccountId,
  description: description,
);

void main() {
  // The worked example from the web fixture.
  final rows = <BalanceTxn>[
    txn(type: 'expense', amount: '18600'),
    txn(type: 'income', amount: '250000', accountId: 'sbi'),
    txn(
      type: 'transfer',
      amount: '5000',
      accountId: 'sbi',
      transferToAccountId: 'cash',
    ),
    txn(type: 'expense', amount: '12500', accountId: 'hdfc'),
  ];
  final accounts = <BalanceAccount>[
    BalanceAccount(id: 'cash', openingBalance: d('4000000')),
    BalanceAccount(id: 'sbi', openingBalance: d('100000')),
    BalanceAccount(id: 'hdfc', openingBalance: d('50000')),
  ];

  test('computeLiveBalances matches the hand-computed worked example', () {
    final b = computeLiveBalances(accounts, rows);
    // cash: 4,000,000 − 18,600 + 5,000 (transfer in)   = 3,986,400
    // sbi:    100,000 + 250,000 − 5,000 (transfer out)  =   345,000
    // hdfc:    50,000 − 12,500                          =    37,500
    expect(b['cash'], d('3986400'));
    expect(b['sbi'], d('345000'));
    expect(b['hdfc'], d('37500'));
  });

  test('applyAccountDeltas(deriveAccountDeltas(txns)) == computeLiveBalances', () {
    final viaDeltas = applyAccountDeltas(accounts, deriveAccountDeltas(rows));
    final direct = computeLiveBalances(accounts, rows);
    expect(viaDeltas, direct);
  });

  test('the single-expense spec example: cash reads opening − expense', () {
    final one = [txn(type: 'expense', amount: '18600')];
    final b = computeLiveBalances(
      [BalanceAccount(id: 'cash', openingBalance: d('4000000'))],
      one,
    );
    expect(b['cash'], d('3981400'));
  });

  test('a transfer to a since-deleted account still moves the source', () {
    final b = computeLiveBalances(
      [BalanceAccount(id: 'sbi', openingBalance: d('100000'))],
      [
        txn(
          type: 'transfer',
          amount: '5000',
          accountId: 'sbi',
          transferToAccountId: 'gone',
        ),
      ],
    );
    expect(b['sbi'], d('95000'));
    expect(b.containsKey('gone'), isFalse);
  });

  test('a delta for an unknown account is ignored', () {
    final b = applyAccountDeltas(
      [BalanceAccount(id: 'sbi', openingBalance: d('100000'))],
      [
        AccountDelta(accountId: 'sbi', delta: d('2000')),
        AccountDelta(accountId: 'ghost', delta: d('999999')),
      ],
    );
    expect(b['sbi'], d('102000'));
    expect(b.containsKey('ghost'), isFalse);
  });

  group('the money invariant: a tracker label cannot move a balance', () {
    // account_balances.dart has no tracker field at all, so this is structural
    // — the test turns that into a pinned promise (mirrors the web test).
    test('legacy [Mode|accountId] prefix still routes a row to its account', () {
      final b = computeLiveBalances(
        [BalanceAccount(id: 'hdfc', openingBalance: d('0'))],
        [
          txn(
            type: 'expense',
            amount: '900',
            accountId: null,
            description: '[UPI|hdfc] lunch',
          ),
        ],
      );
      expect(b['hdfc'], d('-900'));
    });

    test('a plain bracket note is not mistaken for an account tag', () {
      expect(extractAccountId('[urgent] pay rent'), isNull);
      expect(accountOf(txn(type: 'expense', amount: '1', accountId: null,
          description: '[urgent] pay rent')), isNull);
    });
  });
}
