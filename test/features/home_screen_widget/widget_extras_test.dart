import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/budget/domain/budget_spend.dart';
import 'package:finroot_mobile/features/calendar/calendar_events.dart';
import 'package:finroot_mobile/features/home_screen_widget/domain/widget_figures.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetWithSpend _jar(String bucket, String allocated, String spent) {
  final a = Money.parse(allocated);
  final s = Money.parse(spent);
  return BudgetWithSpend(
    budget: BudgetEntity(
      id: bucket,
      bucket: bucket,
      allocated: a,
      period: 'monthly',
      periodStart: DateTime.utc(2026, 11),
    ),
    spent: s,
    utilization: 0,
    remaining: a - s,
  );
}

CalendarEvent _due(
  String title,
  DateTime day, {
  double? amount,
  bool paid = false,
  bool income = false,
}) => CalendarEvent(
  kind: CalendarEventKind.subscription,
  id: '$title-$day',
  day: day,
  title: title,
  amount: amount,
  paid: paid,
  income: income,
);

void main() {
  final now = DateTime(2026, 11, 26, 9);

  group('budget left', () {
    test('spending jars only, as on the Budget screen', () {
      final b = widgetBudget([
        _jar('Needs', '20000', '15000'),
        _jar('Wants', '5000', '3600'),
        _jar('Long-Term Savings', '10000', '0'), // set aside, not spend
      ], masked: false)!;
      expect(b.text, '₹6,400 left of ₹25,000');
      expect(b.pct, 74);
      expect(b.over, isFalse);
    });

    test('over budget', () {
      final b = widgetBudget([_jar('Needs', '10000', '11200')], masked: false)!;
      expect(b.text, '₹1,200 over a ₹10,000 budget');
      expect(b.pct, 100);
      expect(b.over, isTrue);
    });

    test('masked: the share used, never an amount', () {
      final b = widgetBudget([_jar('Needs', '20000', '5000')], masked: true)!;
      expect(b.text, '25% of budget used');
      expect(b.text, isNot(contains('₹')));
    });

    test('no spending budget set: no line', () {
      expect(widgetBudget(const [], masked: false), isNull);
      expect(
        widgetBudget([_jar('Giving', '1000', '0')], masked: false),
        isNull,
      );
    });
  });

  group('next due', () {
    test('the earliest unpaid outgoing item from today on', () {
      final e = nextDue([
        _due('Rent', DateTime(2026, 12, 2), amount: 15000),
        _due('Old', DateTime(2026, 11, 20)), // passed
        _due('EMI', DateTime(2026, 11, 26), paid: true), // paid
        _due('Salary', DateTime(2026, 11, 27), income: true), // money in
        _due('Netflix', DateTime(2026, 11, 28), amount: 649),
      ], now)!;
      expect(e.title, 'Netflix');
    });

    test('due today counts', () {
      expect(nextDue([_due('Gym', DateTime(2026, 11, 26))], now)!.title, 'Gym');
    });

    test('nothing due', () => expect(nextDue(const [], now), isNull));
  });

  test('the widget map carries both, and masks the bill amount', () {
    final events = [_due('Netflix', DateTime(2026, 11, 28), amount: 649)];
    final budgets = [_jar('Needs', '25000', '18600')];
    final open = widgetFigures(
      const [],
      now: now,
      masked: false,
      budgets: budgets,
      events: events,
    ).toMap();
    expect(open['budget'], '₹6,400 left of ₹25,000');
    expect(open['budgetPct'], 74);
    expect(open['dueTitle'], 'Netflix');
    expect(open['dueAmount'], '₹649');
    expect(open['dueDay'], '2026-11-28');

    final hidden = widgetFigures(
      const [],
      now: now,
      masked: true,
      budgets: budgets,
      events: events,
    ).toMap();
    expect(hidden['dueAmount'], '');
    expect(hidden['budget'], '74% of budget used');

    final none = widgetFigures(const [], now: now, masked: false).toMap();
    expect(none['budget'], '');
    expect(none['budgetPct'], -1);
    expect(none['dueTitle'], '');
  });
}
