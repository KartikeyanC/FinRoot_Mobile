import 'package:decimal/decimal.dart';

/// Live account balances — the money rules, ported verbatim from the FinRoot
/// **web** repo's `src/lib/accountBalances.ts` (M1 audit §4, §"what is derived
/// offline"). The web file is the single source of truth (ADR-0008);
/// `account_balances_parity_test.dart` pins this copy against a fixture derived
/// from `accountBalances.test.ts`.
///
/// ```
/// live balance = openingBalance
///              + Σ income into the account
///              − Σ expense from the account
///              − Σ transfers out (account_id)
///              + Σ transfers in (transfer_to_account_id)
/// ```
///
/// Amounts are always positive; direction comes from which side of a move an
/// account sits on. A [BalanceTxn] deliberately has no `trackerId` — assigning
/// a tracker cannot move a balance, structurally (the money invariant).

class BalanceTxn {
  const BalanceTxn({
    required this.type,
    required this.amount,
    this.description,
    this.accountId,
    this.transferToAccountId,
  });

  final String type; // income | expense | transfer
  final Decimal amount;
  final String? description;
  final String? accountId;
  final String? transferToAccountId;
}

class BalanceAccount {
  const BalanceAccount({required this.id, this.openingBalance});

  final String id;

  /// An account created without one starts at zero.
  final Decimal? openingBalance;
}

/// Net movement for one account, as returned by `dashboard_summary`.
class AccountDelta {
  const AccountDelta({required this.accountId, required this.delta});

  final String accountId;
  final Decimal delta;

  factory AccountDelta.fromJson(Map<String, dynamic> json) => AccountDelta(
    accountId: json['account_id'] as String,
    delta: _decimal(json['delta']),
  );
}

final _prefix = RegExp(r'^\[([^\]|]+)\|([^\]]+)\]');

/// Account id out of a legacy `[Mode|accountId]` description prefix. A note that
/// merely starts with a bracket (`[urgent] pay rent`) has no `|` and yields
/// null.
String? extractAccountId(String? description) {
  if (description == null) return null;
  final m = _prefix.firstMatch(description);
  return m?.group(2);
}

/// Which account a transaction belongs to: the real column when set, otherwise
/// the legacy prefix. The column wins even when both are present.
String? accountOf(BalanceTxn txn) =>
    txn.accountId ?? extractAccountId(txn.description);

/// `opening + Σ delta`, ignoring a delta for an account the client does not
/// have (matches [computeLiveBalances], which only ever touches ids already in
/// its map).
Map<String, Decimal> applyAccountDeltas(
  List<BalanceAccount> accounts,
  List<AccountDelta>? deltas,
) {
  final map = <String, Decimal>{
    for (final a in accounts) a.id: a.openingBalance ?? Decimal.zero,
  };
  for (final d in deltas ?? const <AccountDelta>[]) {
    final current = map[d.accountId];
    if (current == null) continue;
    map[d.accountId] = current + d.delta;
  }
  return map;
}

/// Derive the same deltas client-side (offline path). Pinned equal to
/// [computeLiveBalances] by test.
List<AccountDelta> deriveAccountDeltas(List<BalanceTxn> txns) {
  final sums = <String, Decimal>{};
  void add(String? id, Decimal v) {
    if (id == null) return;
    sums[id] = (sums[id] ?? Decimal.zero) + v;
  }

  for (final txn in txns) {
    final amount = txn.amount;
    final accId = accountOf(txn);
    switch (txn.type) {
      case 'transfer':
        add(accId, -amount);
        add(txn.transferToAccountId, amount);
      case 'expense':
        add(accId, -amount);
      case 'income':
        add(accId, amount);
    }
  }

  return [
    for (final e in sums.entries)
      AccountDelta(accountId: e.key, delta: e.value),
  ];
}

/// Live balances straight from the full (cached) ledger — the offline
/// equivalent of `applyAccountDeltas(accts, dashboard_summary.account_deltas)`.
Map<String, Decimal> computeLiveBalances(
  List<BalanceAccount> accounts,
  List<BalanceTxn> txns,
) {
  final map = <String, Decimal>{
    for (final a in accounts) a.id: a.openingBalance ?? Decimal.zero,
  };

  for (final txn in txns) {
    final amount = txn.amount;
    final accId = accountOf(txn);

    if (txn.type == 'transfer') {
      // Each leg independently: a transfer to/from a since-deleted account
      // still moves the surviving side correctly.
      if (accId != null && map.containsKey(accId)) {
        map[accId] = map[accId]! - amount;
      }
      final toId = txn.transferToAccountId;
      if (toId != null && map.containsKey(toId)) {
        map[toId] = map[toId]! + amount;
      }
      continue;
    }

    if (accId == null || !map.containsKey(accId)) continue;
    if (txn.type == 'expense') {
      map[accId] = map[accId]! - amount;
    } else if (txn.type == 'income') {
      map[accId] = map[accId]! + amount;
    }
  }
  return map;
}

Decimal _decimal(Object? v) => Decimal.parse((v ?? 0).toString());
