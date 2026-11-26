import '../../../core/money/money.dart';

/// The fields Quick account management (M8) can set. The web `accounts` form
/// carries more (bank, holder, last4, branch, colour, purposes…); those stay
/// web-only and a mobile edit never clears them — it PATCHes just these
/// columns. [openingDate] is the web `accounts.opening_date` (a plain `date`,
/// the day the opening balance is "as of"); null on create means today.
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.type,
    this.openingBalance,
    this.openingDate,
  });

  final String name;
  final String
  type; // bank | debit | credit | wallet | cash | investment | other
  final Money? openingBalance;

  /// Date only — the time part is ignored.
  final DateTime? openingDate;
}

/// `yyyy-MM-dd`, the shape the web writes to `accounts.opening_date`
/// (`openingDateISO.slice(0, 10)`).
String accountIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parse a stored `opening_date` (`yyyy-MM-dd`, or a full timestamp from an
/// older row) to a local calendar date. Null / garbage → null.
DateTime? parseAccountDate(Object? raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.length < 10) return null;
  final d = DateTime.tryParse(s.substring(0, 10));
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// The PostgREST body for an account write. On create a missing
/// [AccountDraft.openingDate] becomes [today]; on edit it is left out so a
/// date the web set is never cleared.
Map<String, dynamic> accountWriteBody(
  AccountDraft draft, {
  required bool creating,
  DateTime? today,
}) {
  final date =
      draft.openingDate ?? (creating ? (today ?? DateTime.now()) : null);
  return {
    'name': draft.name.trim(),
    'type': draft.type,
    'opening_balance': draft.openingBalance?.amount.toDouble(),
    if (date != null) 'opening_date': accountIsoDate(date),
  };
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
