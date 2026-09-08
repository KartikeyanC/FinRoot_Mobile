import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

/// Money amounts are stored as the exact `numeric(14,2)`-shaped string and
/// round-tripped through [Decimal] — never a float (M1 audit R-9,
/// `core/money/money.dart`). Stored with two fixed decimals so the local value
/// matches the server column and `Money.toStorageString()`. The currency lives
/// in its own text column; the repository layer reassembles
/// `Money(amount, currency)` on read.
class DecimalConverter extends TypeConverter<Decimal, String> {
  const DecimalConverter();

  @override
  Decimal fromSql(String fromDb) => Decimal.parse(fromDb);

  @override
  String toSql(Decimal value) => value.toStringAsFixed(2);
}
