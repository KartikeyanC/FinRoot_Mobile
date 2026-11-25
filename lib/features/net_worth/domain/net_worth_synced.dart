import '../../../core/money/money.dart';
import '../../accounts/domain/account.dart';
import '../../debts/debts.dart';
import '../../investments/domain/investment.dart';
import 'net_worth.dart';

/// Net worth rows that come from elsewhere in the app, read-only here — the
/// web Net Worth page builds the same ones (`src/pages/NetWorth.tsx`,
/// `src/lib/netWorthDebts.ts`), so both apps record the same daily snapshot:
///
///  * every account except credit cards, at its live balance;
///  * every investment, at its current value;
///  * every loan, at what is left to pay (total minus the EMIs marked paid).
///
/// Zero amounts are left out.

/// Web `accountAssetGroup`.
String accountAssetGroup(String type) => switch (type) {
  'cash' || 'wallet' => 'liquid',
  'investment' => 'stocks',
  'bank' || 'debit' => 'bank',
  _ => 'other_asset',
};

/// Web `debtLiabilityGroup`: which liability group a loan shows under.
String debtLiabilityGroup(String category, String lender) {
  final s = '$category $lender'.toLowerCase();
  bool has(String p) => RegExp(p).hasMatch(s);
  if (has(r'\b(home|house|housing|mortgage)\b')) return 'home_loan';
  if (has(r'\b(car|vehicle|auto|bike|transport)\b')) return 'car_loan';
  if (has(r'\bcredit card\b')) return 'credit_card';
  return 'personal_loan';
}

List<NetWorthEntry> syncedNetWorth({
  required List<AccountEntity> accounts,
  required Map<String, Money> balances,
  required List<InvestmentRecord> investments,
  required List<Debt> debts,
}) => [
  for (final a in accounts)
    if (a.type != 'credit')
      if ((balances[a.id] ?? a.openingBalance ?? Money.zero()) case final m
          when !m.isZero)
        NetWorthEntry(
          id: 'synced:account:${a.id}',
          kind: 'asset',
          group: accountAssetGroup(a.type),
          name: a.name.trim().isEmpty ? 'Account' : a.name,
          amount: m,
          source: NetWorthSource.account,
        ),
  for (final r in investments)
    if (r.current case final m when !m.isZero)
      NetWorthEntry(
        id: 'synced:investment:${r.id}',
        kind: 'asset',
        group: switch (r.asset) {
          'mutual_funds' => 'mutual_funds',
          'stocks' => 'stocks',
          _ => 'other_asset',
        },
        name: r.name,
        amount: m,
        source: NetWorthSource.investment,
      ),
  for (final d in debts)
    if (d.remaining > 0)
      NetWorthEntry(
        id: 'synced:debt:${d.id}',
        kind: 'liability',
        group: debtLiabilityGroup(d.category, d.lender),
        name: d.lender.trim().isEmpty ? 'Loan' : d.lender,
        amount: Money.parse(
          ((d.remaining * 100).roundToDouble() / 100).toStringAsFixed(2),
          d.currency,
        ),
        source: NetWorthSource.debt,
      ),
];
