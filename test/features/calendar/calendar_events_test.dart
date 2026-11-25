import 'package:finroot_mobile/features/calendar/calendar_events.dart';
import 'package:finroot_mobile/features/debts/debts.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/subscriptions/subscriptions.dart';
import 'package:flutter_test/flutter_test.dart';

// The same cases as the web's calendar occurrence tests: both apps put the
// same things on the same days.
DateTime m(int y, int mo) => DateTime(y, mo);
DateTime next(DateTime month) => DateTime(month.year, month.month + 1);

List<int> days(List<CalendarEvent> es) => [for (final e in es) e.day.day];

Reminder reminder(
  String id,
  String due, {
  String? frequency,
  String status = 'scheduled',
  String? source,
}) => Reminder.fromRow({
  'id': id,
  'title': 'Rent',
  'context': 'fixed_due',
  'due_date': due,
  'status': status,
  'amount': 15000,
  'frequency': frequency,
  'source': source,
});

void main() {
  group('reminders', () {
    test('a monthly one shows in every month, past or future', () {
      final r = [reminder('r1', '2026-09-05', frequency: 'monthly')];
      for (final month in [m(2026, 9), m(2026, 10), m(2027, 3)]) {
        expect(days(remindersIn(r, month, next(month))), [5]);
      }
      expect(remindersIn(r, m(2026, 8), next(m(2026, 8))), isEmpty);
    });

    test('a quarterly one every third month', () {
      final r = [reminder('r1', '2026-01-31', frequency: 'quarterly')];
      expect(days(remindersIn(r, m(2026, 4), next(m(2026, 4)))), [30]);
      expect(remindersIn(r, m(2026, 5), next(m(2026, 5))), isEmpty);
      expect(days(remindersIn(r, m(2026, 7), next(m(2026, 7)))), [31]);
    });

    test('done ones and a debt\'s EMI reminders are left out', () {
      final r = [
        reminder('r1', '2026-11-05', status: 'completed'),
        reminder('r2', '2026-11-06', source: 'debt'),
        reminder('r3', '2026-11-07'),
      ];
      expect(days(remindersIn(r, m(2026, 11), next(m(2026, 11)))), [7]);
    });
  });

  group('subscriptions', () {
    TrackedSubscription sub(
      String renewal, {
      String frequency = 'monthly',
      int interval = 1,
      String status = 'active',
    }) => TrackedSubscription.fromRow({
      'id': 's1',
      'name': 'Netflix',
      'amount': 649,
      'frequency': frequency,
      'interval_months': interval,
      'renewal_date': renewal,
      'status': status,
    });

    test('billed on the 31st: end of February, then back to the 31st', () {
      final s = [sub('2027-01-31')];
      expect(days(subscriptionsIn(s, m(2027, 2), next(m(2027, 2)))), [28]);
      expect(days(subscriptionsIn(s, m(2027, 3), next(m(2027, 3)))), [31]);
    });

    test('every 3 months', () {
      final s = [sub('2026-11-10', interval: 3)];
      expect(days(subscriptionsIn(s, m(2026, 11), next(m(2026, 11)))), [10]);
      expect(subscriptionsIn(s, m(2026, 12), next(m(2026, 12))), isEmpty);
      expect(days(subscriptionsIn(s, m(2027, 2), next(m(2027, 2)))), [10]);
    });

    test('weekly renews four or five times a month', () {
      final s = [sub('2026-11-02', frequency: 'weekly')];
      expect(days(subscriptionsIn(s, m(2026, 11), next(m(2026, 11)))), [
        2,
        9,
        16,
        23,
        30,
      ]);
    });

    test('a cancelled one is left out', () {
      final s = [sub('2026-11-10', status: 'cancel')];
      expect(subscriptionsIn(s, m(2026, 11), next(m(2026, 11))), isEmpty);
    });
  });

  group('recurring items', () {
    RecurringItem item(
      String due,
      String frequency, {
      bool active = true,
      String type = 'expense',
    }) => RecurringItem.fromRow({
      'id': 'i1',
      'type': type,
      'name': 'Salary',
      'category': 'Salary',
      'amount': 85000,
      'frequency': frequency,
      'next_due_date': due,
      'is_active': active,
    });

    test('weekly, from the next due date on', () {
      final r = [item('2026-11-12', 'weekly')];
      expect(days(recurringIn(r, m(2026, 11), next(m(2026, 11)))), [
        12,
        19,
        26,
      ]);
    });

    test('one-time shows once; inactive not at all', () {
      expect(
        days(
          recurringIn(
            [item('2026-11-20', 'one-time')],
            m(2026, 11),
            next(m(2026, 11)),
          ),
        ),
        [20],
      );
      expect(
        recurringIn(
          [item('2026-11-20', 'monthly', active: false)],
          m(2026, 11),
          next(m(2026, 11)),
        ),
        isEmpty,
      );
    });

    test('income items read as income', () {
      final e = recurringIn(
        [item('2026-11-01', 'monthly', type: 'income')],
        m(2026, 11),
        next(m(2026, 11)),
      ).single;
      expect(e.income, isTrue);
      expect(e.label, 'Income due');
    });
  });

  test('EMIs: each on its date, paid ones marked', () {
    final debt = Debt.fromRow({
      'id': 'd1',
      'lender': 'HDFC',
      'currency': 'INR',
      'total_amount': 30000,
      'monthly': 10000,
      'duration': 3,
      'installments': [
        {
          'month': 1,
          'dueDate': '2026-10-05',
          'amount': 10000,
          'status': 'paid',
        },
        {
          'month': 2,
          'dueDate': '2026-11-05',
          'amount': 10000,
          'status': 'pending',
        },
        {
          'month': 3,
          'dueDate': '2026-12-05',
          'amount': 10000,
          'status': 'pending',
        },
      ],
    });
    final oct = emisIn([debt], m(2026, 10), next(m(2026, 10))).single;
    expect(oct.paid, isTrue);
    expect(oct.label, 'EMI paid');
    final nov = emisIn([debt], m(2026, 11), next(m(2026, 11))).single;
    expect(nov.title, 'HDFC · EMI 2/3');
    expect(nov.label, 'EMI due');
    expect(nov.route, '/debts');
  });

  test('eventsByDay groups by day, kinds in order', () {
    final g = eventsByDay([
      CalendarEvent(
        kind: CalendarEventKind.emi,
        id: 'a',
        day: DateTime(2026, 11, 5),
        title: 'B',
      ),
      CalendarEvent(
        kind: CalendarEventKind.reminder,
        id: 'b',
        day: DateTime(2026, 11, 5),
        title: 'A',
      ),
    ]);
    expect(g[5]!.map((e) => e.kind), [
      CalendarEventKind.reminder,
      CalendarEventKind.emi,
    ]);
  });
}
