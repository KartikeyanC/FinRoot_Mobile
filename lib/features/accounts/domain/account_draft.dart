import '../../../core/money/money.dart';

/// The fields Quick account management (M8) can set. The web `accounts` form
/// carries more (bank, holder, last4, branch, colour, purposes…); those stay
/// web-only and a mobile edit never clears them — it PATCHes just these
/// columns. Opening date is set to "today" on create and is web-only to change.
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    this.openingBalance,
  });

  final String name;
  final String type; // bank | debit | credit | wallet | cash | investment | other
  final Money? openingBalance;
}

/// Account types, in the order the picker shows them (web `AccountType`).
const List<String> kAccountTypes = [
  'bank',
  'debit',
  'credit',
  'wallet',
  'cash',
  'investment',
  'other',
];

String accountTypeLabel(String type) => switch (type) {
  'bank' => 'Bank',
  'debit' => 'Debit card',
  'credit' => 'Credit card',
  'wallet' => 'Wallet',
  'cash' => 'Cash',
  'investment' => 'Investment',
  _ => 'Other',
};

abstract final class AccountValidators {
  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter an account name';
    if (v.length > 80) return 'That name is too long';
    return null;
  }

  /// Opening balance is optional; if given it must parse and be within
  /// `numeric(14,2)`. It may be negative (a credit card starts in the red).
  static String? openingBalance(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final money = Money.tryParse(raw);
    if (money == null) return 'Enter a valid amount';
    if (money.amount.abs() > Money.parse('999999999999.99').amount) {
      return 'That amount is too large';
    }
    return null;
  }
}
