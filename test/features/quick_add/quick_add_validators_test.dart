import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('amount', () {
    test('rejects empty / junk', () {
      expect(QuickAddValidators.amount(null), isNotNull);
      expect(QuickAddValidators.amount(''), isNotNull);
      expect(QuickAddValidators.amount('abc'), isNotNull);
    });

    test('rejects zero and negative', () {
      expect(QuickAddValidators.amount('0'), isNotNull);
      expect(QuickAddValidators.amount('-5'), isNotNull);
    });

    test('rejects an amount past numeric(14,2)', () {
      expect(QuickAddValidators.amount('1000000000000000'), isNotNull);
    });

    test('accepts a normal amount, with or without a symbol / commas', () {
      expect(QuickAddValidators.amount('250'), isNull);
      expect(QuickAddValidators.amount('18,600.50'), isNull);
      expect(QuickAddValidators.amount('₹1200'), isNull);
    });
  });

  group('category', () {
    test('required only for entry kinds', () {
      expect(QuickAddValidators.category(null, required: true), isNotNull);
      expect(QuickAddValidators.category('Food & Dining', required: true), isNull);
      expect(QuickAddValidators.category(null, required: false), isNull);
    });
  });

  test('note caps at 400 characters', () {
    expect(QuickAddValidators.note('x' * 400), isNull);
    expect(QuickAddValidators.note('x' * 401), isNotNull);
  });

  test('occurredAt rejects a future date', () {
    final now = DateTime(2026, 9, 9, 12);
    expect(
      QuickAddValidators.occurredAt(DateTime(2026, 9, 8), now: now),
      isNull,
    );
    expect(
      QuickAddValidators.occurredAt(DateTime(2026, 9, 10), now: now),
      isNotNull,
    );
  });

  group('transferAccounts', () {
    test('needs both ends, and they must differ', () {
      expect(
        QuickAddValidators.transferAccounts(fromId: null, toId: 'b'),
        isNotNull,
      );
      expect(
        QuickAddValidators.transferAccounts(fromId: 'a', toId: null),
        isNotNull,
      );
      expect(
        QuickAddValidators.transferAccounts(fromId: 'a', toId: 'a'),
        isNotNull,
      );
      expect(
        QuickAddValidators.transferAccounts(fromId: 'a', toId: 'b'),
        isNull,
      );
    });
  });

  test('QuickAddKind maps to wire type and category list', () {
    expect(QuickAddKind.expense.txnType.wire, 'expense');
    expect(QuickAddKind.income.categories, isNotEmpty);
    expect(QuickAddKind.transfer.categories, isEmpty);
  });
}
