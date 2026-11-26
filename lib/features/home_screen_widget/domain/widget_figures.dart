import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../domain/constants.dart';
import '../../budget/domain/budget_spend.dart';
import '../../calendar/calendar_events.dart';
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
    this.budget,
    this.budgetPct,
    this.budgetOver = false,
    this.dueTitle,
    this.dueAmount,
    this.dueDay,
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

  /// "₹6,400 left of ₹25,000": the spending jars, as on the Budget screen.
  /// Null when no spending budget is set this month.
  final String? budget;

  /// Share of the budget spent, 0 to 100 (capped for the bar).
  final int? budgetPct;
  final bool budgetOver;

  /// The next unpaid thing due, from today on: "Netflix".
  final String? dueTitle;

  /// Its amount ("₹649"); null when masked or when it has none.
  final String? dueAmount;

  /// "yyyy-MM-dd" it falls due; the widget words it ("tomorrow", "in 3 days")
  /// and drops it once the day has passed.
  final String? dueDay;

  Map<String, Object> toMap() => {
    'today': today,
    'month': month,
    'masked': masked,
    'zero': formatWidgetAmount(Decimal.zero),
    'day': day,
    'monthKey': monthKey,
    'budget': budget ?? '',
    'budgetPct': budgetPct ?? -1,
    'budgetOver': budgetOver,
    'dueTitle': dueTitle ?? '',
    'dueAmount': dueAmount ?? '',
    'dueDay': dueDay ?? '',
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetFigures &&
      other.today == today &&
      other.month == month &&
      other.masked == masked &&
      other.day == day &&
      other.monthKey == monthKey &&
      other.budget == budget &&
      other.budgetPct == budgetPct &&
      other.budgetOver == budgetOver &&
      other.dueTitle == dueTitle &&
      other.dueAmount == dueAmount &&
      other.dueDay == dueDay;

  @override
  int get hashCode => Object.hash(
    today,
    month,
    masked,
    day,
    monthKey,
    budget,
    budgetPct,
    budgetOver,
    dueTitle,
    dueAmount,
    dueDay,
  );

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
  List<BudgetWithSpend> budgets = const [],
  List<CalendarEvent> events = const [],
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
  final monthKey = '${now.year}-${_two(now.month)}';
  final b = widgetBudget(budgets, masked: masked);
  final due = nextDue(events, now);
  final dueAmount = due?.amount;
  return WidgetFigures(
    today: formatWidgetAmount(today),
    month: formatWidgetAmount(month),
    masked: masked,
    day: '$monthKey-${_two(now.day)}',
    monthKey: monthKey,
    budget: b?.text,
    budgetPct: b?.pct,
    budgetOver: b?.over ?? false,
    dueTitle: due?.title,
    dueAmount: due == null || dueAmount == null || masked
        ? null
        : formatWidgetAmount(
            Money.parse(
              dueAmount.toStringAsFixed(2),
              due.currency,
            ).toInrMoney().amount,
          ),
    dueDay: due == null ? null : _ymd(due.day),
  );
}

String _two(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// The month's spending budget as the Budget screen counts it: the spending
/// jars only (savings jars are money set aside), allocated minus spent. Null
/// when nothing is allocated. Masked: the share used, never an amount.
({String text, int pct, bool over})? widgetBudget(
  List<BudgetWithSpend> list, {
  required bool masked,
}) {
  final spendable = [
    for (final b in list)
      if (!b.isNonExpense) b,
  ];
  final allocated = spendable.fold(
    Decimal.zero,
    (s, b) => s + b.budget.allocated.amount,
  );
  if (allocated <= Decimal.zero) return null;
  final spent = spendable.fold(Decimal.zero, (s, b) => s + b.spent.amount);
  final left = allocated - spent;
  final used = (spent.toDouble() / allocated.toDouble() * 100).round();
  final over = left < Decimal.zero;
  final String text;
  if (masked) {
    text = over ? 'Over budget' : '$used% of budget used';
  } else if (over) {
    text =
        '${formatWidgetAmount(-left)} over a '
        '${formatWidgetAmount(allocated)} budget';
  } else {
    text =
        '${formatWidgetAmount(left)} left of '
        '${formatWidgetAmount(allocated)}';
  }
  return (text: text, pct: used.clamp(0, 100), over: over);
}

/// The first unpaid outgoing event on or after today: a bill, EMI,
/// subscription renewal or reminder. Income items are not "due".
CalendarEvent? nextDue(List<CalendarEvent> events, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  CalendarEvent? best;
  for (final e in events) {
    if (e.paid || e.income || e.day.isBefore(today)) continue;
    if (best == null || e.day.isBefore(best.day)) best = e;
  }
  return best;
}

/// Whole rupees, grouped the Indian way ("₹18,600", "₹1,24,000"), switching
/// to the short form from a crore so it still fits half a widget.
String formatWidgetAmount(Decimal amount) {
  final v = amount.toDouble();
  return v.abs() >= 10000000 ? MoneyFormat.short(v) : MoneyFormat.compact(v);
}
