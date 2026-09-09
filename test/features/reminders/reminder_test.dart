import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:flutter_test/flutter_test.dart';

Reminder _r({
  required DateTime due,
  ReminderContext context = ReminderContext.fixedDue,
  ReminderFrequency? frequency,
  String status = 'scheduled',
  String? notes,
}) => Reminder(
  id: 'r1',
  title: 'HDFC card',
  context: context,
  dueDate: due,
  status: status,
  frequency: frequency,
  notes: notes,
);

void main() {
  group('rolledForward (display transform, ported from web rollForward)', () {
    test('a future reminder is unchanged', () {
      final r = _r(due: DateTime(2026, 12, 2));
      expect(
        identical(r.rolledForward(now: DateTime(2026, 9, 9)), r),
        isTrue,
      );
    });

    test('a past one-off reads as completed', () {
      final r = _r(due: DateTime(2026, 8, 2));
      final rolled = r.rolledForward(now: DateTime(2026, 9, 9));
      expect(rolled.isCompleted, isTrue);
    });

    test('a past monthly fixed-due jumps to the next occurrence', () {
      final r = _r(
        due: DateTime(2026, 6, 15),
        frequency: ReminderFrequency.monthly,
      );
      final rolled = r.rolledForward(now: DateTime(2026, 9, 9));
      expect(rolled.dueDate, DateTime(2026, 9, 15));
      expect(rolled.isCompleted, isFalse);
    });

    test('a past quarterly fixed-due steps by three months', () {
      final r = _r(
        due: DateTime(2026, 1, 10),
        frequency: ReminderFrequency.quarterly,
      );
      final rolled = r.rolledForward(now: DateTime(2026, 9, 9));
      expect(rolled.dueDate, DateTime(2026, 10, 10));
    });

    test('a completed reminder is never rolled', () {
      final r = _r(due: DateTime(2020, 1, 2), status: 'completed');
      expect(r.rolledForward(now: DateTime(2026, 9, 9)).dueDate,
          DateTime(2020, 1, 2));
    });
  });

  group('reminderMessage', () {
    test('a custom note wins', () {
      final r = _r(due: DateTime(2026, 9, 12), notes: 'pay from savings');
      expect(reminderMessage(r, now: DateTime(2026, 9, 9)), 'pay from savings');
    });

    test('fixed-due phrases the countdown', () {
      final r = _r(due: DateTime(2026, 9, 12));
      expect(
        reminderMessage(r, now: DateTime(2026, 9, 9)),
        'Reminder: your HDFC card payment is due in 3 days.',
      );
    });

    test('balance-buffer has its own wording', () {
      final r = _r(
        due: DateTime(2026, 9, 12),
        context: ReminderContext.balanceBuffer,
      );
      expect(reminderMessage(r, now: DateTime(2026, 9, 9)),
          contains('check your funding balance'));
    });
  });

  test('fromRow parses the DB shape and keeps web-only fields in extra', () {
    final r = Reminder.fromRow({
      'id': 'x',
      'title': 'FD maturity',
      'context': 'maturity',
      'due_date': '2026-11-02',
      'status': 'scheduled',
      'amount': '150000.00',
      'currency': 'INR',
      'maturity_leads': ['30d', '7d'],
      'verify_liquidity': true,
    });
    expect(r.context, ReminderContext.maturity);
    expect(r.dueDate, DateTime(2026, 11, 2));
    expect(r.amount!.amount.toDouble(), 150000);
    expect(r.amount!.currency, 'INR');
    expect(r.extra['maturity_leads'], ['30d', '7d']);
    expect(r.extra['verify_liquidity'], true);
  });

  test('context wire values match the DB CHECK', () {
    expect(ReminderContext.fixedDue.wire, 'fixed_due');
    expect(ReminderContext.balanceBuffer.wire, 'balance_buffer');
    expect(ReminderContext.maturity.wire, 'maturity');
  });
}
