import '../../../core/money/money.dart';

/// An account as the UI needs it. The M4 cache holds a deliberate subset of the
/// web `accounts` table — enough to name and pick an account, not the full
/// management record (that's M8). Balances stay server-derived (ADR-0006).
class AccountEntity {
  const AccountEntity({
    required this.id,
    required this.name,
    required this.type,
    this.openingBalance,
    this.color,
    this.icon,
  });

  final String id;
  final String name;

  /// `bank` | `debit` | `credit` | `wallet` | `cash` | `investment` | `other`
  /// (web `AccountType`). Free text here — the cache mirrors whatever the
  /// server sent.
  final String type;

  final Money? openingBalance;
  final String? color;
  final String? icon;

  /// Human label for the type, e.g. `Bank` · `Credit card` · `Cash`.
  String get typeLabel => switch (type) {
    'bank' => 'Bank',
    'debit' => 'Debit card',
    'credit' => 'Credit card',
    'wallet' => 'Wallet',
    'cash' => 'Cash',
    'investment' => 'Investment',
    _ => 'Other',
  };
}
