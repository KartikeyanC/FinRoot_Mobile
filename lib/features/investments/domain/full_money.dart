import 'package:intl/intl.dart';

import '../../../core/money/currency.dart';
import '../../../core/money/money.dart';

/// A money amount in full, always with two decimals and Indian grouping for
/// rupees ("₹1,42,929.31", "-₹1,899.60") — the broker-app view the
/// Investments screens use for values and profit / loss, never "₹1.9k".
String fullMoney(Money m) {
  final symbol = currencySymbol(m.currency);
  final f = NumberFormat.currency(
    locale: m.currency == 'INR' ? 'en_IN' : 'en_US',
    symbol: symbol,
    decimalDigits: 2,
  );
  return f.format(m.amount.toDouble());
}
