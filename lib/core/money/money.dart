import 'package:decimal/decimal.dart';

import 'currency.dart';
import 'money_format.dart';

/// A money amount as an exact [Decimal] plus its currency code.
///
/// **Never use `double` for money in this app.** The server column is
/// `numeric(14,2)` (web BR-023); parsing through `double` loses cents at scale.
/// JSON in/out is via strings.
class Money implements Comparable<Money> {
  Money(this.amount, [this.currency = workspaceCurrency]);

  factory Money.zero([String currency = workspaceCurrency]) =>
      Money(Decimal.zero, currency);

  /// Parse a server/string value. Throws [FormatException] on junk.
  factory Money.parse(String raw, [String currency = workspaceCurrency]) =>
      Money(Decimal.parse(raw.trim()), currency);

  /// Lenient parse for user input; returns null instead of throwing.
  static Money? tryParse(String raw, [String currency = workspaceCurrency]) {
    final cleaned = raw.replaceAll(RegExp(r'[,\s₹$€£]'), '').trim();
    if (cleaned.isEmpty) return null;
    final d = Decimal.tryParse(cleaned);
    return d == null ? null : Money(d, currency);
  }

  final Decimal amount;
  final String currency;

  bool get isZero => amount == Decimal.zero;
  bool get isNegative => amount < Decimal.zero;
  bool get isPositive => amount > Decimal.zero;

  Money get abs => Money(amount.abs(), currency);
  Money operator -() => Money(-amount, currency);

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount - other.amount, currency);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// This amount expressed in INR using the fixed FX table (display only).
  Money toInrMoney() =>
      Money(Decimal.parse(toInr(amount.toDouble(), currency).toString()));

  /// `numeric(14,2)`-shaped string for sending to the server.
  String toStorageString() => amount.toStringAsFixed(2);

  String format() => MoneyFormat.money(amount.toDouble(), currency: currency);
  String formatShort() =>
      MoneyFormat.short(amount.toDouble(), currency: currency);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amount.compareTo(other.amount);
  }

  void _assertSameCurrency(Money other) {
    assert(
      other.currency == currency,
      'Money arithmetic across currencies ($currency vs ${other.currency}). '
      'Convert through toInrMoney() first.',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => 'Money(${toStorageString()} $currency)';
}
