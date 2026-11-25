import 'package:decimal/decimal.dart';

import '../../../core/money/money_format.dart';
import '../../../domain/constants.dart';
import '../../transactions/domain/transaction.dart';

/// What the FinRoot home-screen widget shows: today's and this month's spend,
/// already formatted (the widget renders strings, it never sees a
/// transaction). Android side: `FinRootWidget.kt` / `HomeWidgetStore`.
///
/// [day] and [monthKey] say which day and month the figures belong to, so the
/// widget can show ₹0 on a new morning before FinRoot is opened.
class WidgetFigures {
  const WidgetFigures({
    required this.today,
    required this.month,
    required this.masked,
    required this.day,
    required this.monthKey,
  });

  final String today;
  final String month;

  /// "Hide income" is on: the widget shows ₹ •••• instead. The home screen is
  /// the most public place FinRoot appears, so spend hides with income.
  final bool masked;

  /// "yyyy-MM-dd", local.
  final String day;

  /// "yyyy-MM", local.
  final String monthKey;

  Map<String, Object> toMap() => {
    'today': today,
    'month': month,
    'masked': masked,
    'zero': formatWidgetAmount(Decimal.zero),
    'day': day,
    'monthKey': monthKey,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetFigures &&
      other.today == today &&
      other.month == month &&
      other.masked == masked &&
      other.day == day &&
      other.monthKey == monthKey;

  @override
  int get hashCode => Object.hash(today, month, masked, day, monthKey);

  @override
  String toString() =>
      'WidgetFigures(today: $today, month: $month, masked: $masked, '
      '$day, $monthKey)';
}

/// The start of [now]'s month, local — where the widget's query begins.
DateTime monthStart(DateTime now) => DateTime(now.year, now.month);

/// Today's and this month's spend from [rows]: expenses only (income and
/// transfers are not spend), each folded to INR first as the dashboard does
/// (`toInrMoney`, web `finance.ts`). Rows outside [now]'s month are ignored,
/// so passing extra rows is harmless.
WidgetFigures widgetFigures(
  Iterable<TransactionEntity> rows, {
  required DateTime now,
  required bool masked,
}) {
  var today = Decimal.zero;
  var month = Decimal.zero;
  for (final t in rows) {
    if (t.type != TxnType.expense) continue;
    final at = t.occurredAt.toLocal();
    if (at.year != now.year || at.month != now.month) continue;
    final inr = t.amount.toInrMoney().amount;
    month += inr;
    if (at.day == now.day) today += inr;
  }
  String two(int n) => n.toString().padLeft(2, '0');
  final monthKey = '${now.year}-${two(now.month)}';
  return WidgetFigures(
    today: formatWidgetAmount(today),
    month: formatWidgetAmount(month),
    masked: masked,
    day: '$monthKey-${two(now.day)}',
    monthKey: monthKey,
  );
}

/// Whole rupees, grouped the Indian way ("₹18,600", "₹1,24,000"), switching
/// to the short form from a crore so it still fits half a widget.
String formatWidgetAmount(Decimal amount) {
  final v = amount.toDouble();
  return v.abs() >= 10000000 ? MoneyFormat.short(v) : MoneyFormat.compact(v);
}
