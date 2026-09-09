import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/voice/domain/voice_parse.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 9, 14, 30);

VoiceDraft _p(String s) => parseUtterance(s, now: _now);

void main() {
  group('amount', () {
    test('plain number', () {
      expect(_p('spent 400 on groceries').amount!.amount.toDouble(), 400);
    });
    test('with rupee words / symbols', () {
      expect(_p('paid rs 1,200 rent').amount!.amount.toDouble(), 1200);
      expect(_p('₹250 for lunch').amount!.amount.toDouble(), 250);
      expect(_p('500 rupees on fuel').amount!.amount.toDouble(), 500);
    });
    test('k / thousand / lakh multipliers', () {
      expect(_p('2.5k on shopping').amount!.amount.toDouble(), 2500);
      expect(_p('12 thousand for rent').amount!.amount.toDouble(), 12000);
      expect(_p('1.2 lakh on travel').amount!.amount.toDouble(), 120000);
    });
    test('decimals', () {
      expect(_p('spent 99.50 on snacks').amount!.amount.toDouble(), 99.5);
    });
    test('no number -> not understood', () {
      final d = _p('bought some groceries');
      expect(d.amount, isNull);
      expect(d.understood, isFalse);
    });
  });

  group('kind', () {
    test('expense by default and on spend verbs', () {
      expect(_p('400 on food').kind, QuickAddKind.expense);
      expect(_p('paid 400 for food').kind, QuickAddKind.expense);
      expect(_p('bought a book for 300').kind, QuickAddKind.expense);
    });
    test('income verbs', () {
      expect(_p('got 5000 salary').kind, QuickAddKind.income);
      expect(_p('received 2000 from freelance').kind, QuickAddKind.income);
    });
    test('transfer verbs', () {
      expect(_p('moved 5000 to savings').kind, QuickAddKind.transfer);
    });
  });

  group('category', () {
    test('expense synonyms map to a seed category', () {
      expect(_p('spent 400 on groceries').category, 'Food & Dining');
      expect(_p('250 for petrol').category, 'Transport');
      expect(_p('paid 12000 rent').category, 'Rent');
      expect(_p('300 on medicines').category, 'Healthcare');
      expect(_p('600 netflix subscription').category, 'Subscriptions');
    });
    test('income synonyms', () {
      expect(_p('got 5000 as salary').category, 'Salary');
      expect(_p('received 8000 freelance').category, 'Freelance');
    });
    test('unknown category stays null', () {
      expect(_p('spent 400 on random stuff').category, isNull);
    });
  });

  group('payment mode', () {
    test('recognised modes', () {
      expect(_p('paid 400 by upi').paymentMode, 'UPI');
      expect(_p('400 with card').paymentMode, 'Card');
      expect(_p('paid 400 cash').paymentMode, 'Cash');
      expect(_p('400 via phonepe').paymentMode, 'UPI');
      expect(_p('400 through net banking').paymentMode, 'Net Banking');
    });
    test('none -> null', () {
      expect(_p('spent 400 on food').paymentMode, isNull);
    });
  });

  group('date', () {
    test('defaults to now', () {
      expect(_p('spent 400 on food').occurredAt, _now);
    });
    test('yesterday / day before', () {
      expect(_p('spent 400 yesterday').occurredAt,
          DateTime(2026, 9, 8, 14, 30));
      expect(_p('spent 400 day before yesterday').occurredAt,
          DateTime(2026, 9, 7, 14, 30));
    });
    test('N days ago', () {
      expect(_p('paid 400 5 days ago').occurredAt,
          DateTime(2026, 9, 4, 14, 30));
    });
    test('weekday walks back to the most recent past one', () {
      // 2026-09-09 is a Wednesday; "monday" -> 2026-09-07
      expect(_p('spent 400 on monday').occurredAt.day, 7);
      // "friday" -> the previous Friday, 2026-09-04
      expect(_p('spent 400 last friday').occurredAt.day, 4);
    });
  });

  group('note', () {
    test('object of "for" becomes the note', () {
      expect(_p('bought coffee for 250').note, 'Coffee');
    });
    test('the object of "for"/"bought" is kept even if it drove the category', () {
      expect(_p('spent 400 on groceries').note, 'Groceries');
    });
    test('dropped only when it is literally the category name', () {
      expect(_p('spent 400 on rent').note, isNull); // "rent" == category "Rent"
    });
    test('note survives trailing mode / date', () {
      expect(_p('paid for parking with card yesterday 60').note, 'Parking');
    });
  });

  group('resolvedCategory', () {
    test('falls back to Other when the parser found nothing', () {
      expect(resolvedCategory(_p('spent 400 on stuff')), 'Other');
      expect(resolvedCategory(_p('got 5000 somehow')), 'Other');
    });
  });

  test('a full sentence parses end to end', () {
    final d = _p('spent 400 on groceries with card yesterday');
    expect(d.kind, QuickAddKind.expense);
    expect(d.amount!.amount.toDouble(), 400);
    expect(d.category, 'Food & Dining');
    expect(d.paymentMode, 'Card');
    expect(d.occurredAt, DateTime(2026, 9, 8, 14, 30));
    expect(d.understood, isTrue);
  });
}
