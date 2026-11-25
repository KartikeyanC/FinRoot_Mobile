import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/net_worth/domain/net_worth.dart';
import 'package:finroot_mobile/features/net_worth/domain/net_worth_synced.dart';
import 'package:flutter_test/flutter_test.dart';

// The same rows the web Net Worth page builds (NetWorth.tsx derivedAssets,
// netWorthDebts.ts), so both apps record the same daily snapshot.
Money inr(String v) => Money.parse(v);

Debt debt({String category = 'Other', String lender = 'HDFC'}) => Debt.fromRow({
  'id': 'd1',
  'lender': lender,
  'category': category,
  'currency': 'INR',
  'total_amount': 30000,
  'monthly': 10000,
  'duration': 3,
  'installments': [
    {'month': 1, 'dueDate': '2026-09-05', 'amount': 10000, 'status': 'paid'},
    {'month': 2, 'dueDate': '2026-10-05', 'amount': 10000, 'status': 'pending'},
    {'month': 3, 'dueDate': '2026-11-05', 'amount': 10000, 'status': 'pending'},
  ],
});

void main() {
  test('accounts at their live balance; credit cards and zeros left out', () {
    final rows = syncedNetWorth(
      accounts: const [
        AccountEntity(id: 'a1', name: 'HDFC Savings', type: 'bank'),
        AccountEntity(id: 'a2', name: 'Wallet', type: 'wallet'),
        AccountEntity(id: 'a3', name: 'Amex', type: 'credit'),
        AccountEntity(id: 'a4', name: 'Empty', type: 'cash'),
      ],
      balances: {
        'a1': inr('52000'),
        'a2': inr('800'),
        'a3': inr('-12000'),
        'a4': inr('0'),
      },
      investments: const [],
      debts: const [],
    );
    expect(
      [for (final r in rows) (r.name, r.group, r.amount)],
      [
        ('HDFC Savings', 'bank', inr('52000')),
        ('Wallet', 'liquid', inr('800')),
      ],
    );
    expect(rows.every((r) => r.synced && r.isAsset), isTrue);
    expect(rows.first.source, NetWorthSource.account);
  });

  test('investments at current value, grouped like the web', () {
    final rows = syncedNetWorth(
      accounts: const [],
      balances: const {},
      investments: const [
        InvestmentRecord(
          id: 'i1',
          asset: 'mutual_funds',
          currency: 'INR',
          fields: {'fundName': 'Parag Parikh Flexi Cap', 'invested': 90000},
          derived: {'currentValue': 104500},
        ),
        InvestmentRecord(
          id: 'i2',
          asset: 'gold',
          currency: 'INR',
          fields: {},
          derived: {'currentValue': 0, 'invested': 0},
        ),
      ],
      debts: const [],
    );
    expect(rows, hasLength(1));
    expect(rows.single.group, 'mutual_funds');
    expect(rows.single.amount.amount, Decimal.parse('104500'));
    expect(rows.single.source, NetWorthSource.investment);
  });

  test('loans at what is left to pay, as liabilities', () {
    final rows = syncedNetWorth(
      accounts: const [],
      balances: const {},
      investments: const [],
      debts: [debt(category: 'Housing', lender: 'SBI')],
    );
    final r = rows.single;
    expect(r.isAsset, isFalse);
    expect(r.group, 'home_loan');
    expect(r.amount, inr('20000'));
    expect(r.source, NetWorthSource.debt);
    expect(NetWorthTotals.of(rows).netWorth, inr('-20000'));
  });

  test('liability groups match the web', () {
    expect(debtLiabilityGroup('Housing', 'SBI'), 'home_loan');
    expect(debtLiabilityGroup('Other', 'HDFC Home Loans'), 'home_loan');
    expect(debtLiabilityGroup('Transport', 'Bajaj'), 'car_loan');
    expect(debtLiabilityGroup('Other', 'Maruti car loan'), 'car_loan');
    expect(debtLiabilityGroup('Other', 'ICICI credit card EMI'), 'credit_card');
    expect(debtLiabilityGroup('Shopping', 'Rahul'), 'personal_loan');
    expect(accountAssetGroup('investment'), 'stocks');
    expect(accountAssetGroup('other'), 'other_asset');
  });
}
