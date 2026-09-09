import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/budget/domain/budget_buckets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the ported category→bucket bridge against the FinRoot **web** repo's
/// `src/lib/budgetBuckets.test.ts` (single source of truth — ADR-0008).

BudgetSpendInput _txn(
  String category,
  String amount,
  DateTime at, {
  String type = 'expense',
}) => (
  type: type,
  category: category,
  amount: Decimal.parse(amount),
  occurredAt: at,
);

void main() {
  group('bucketForCategory', () {
    test('essentials → Needs, discretionary → Play, Education own jar', () {
      expect(bucketForCategory('Rent'), 'Needs');
      expect(bucketForCategory('Food & Dining'), 'Needs');
      expect(bucketForCategory('Entertainment'), 'Play');
      expect(bucketForCategory('Travel'), 'Play');
      expect(bucketForCategory('Education'), 'Education');
    });

    test('unknown / null / empty → Needs (spending never vanishes)', () {
      expect(bucketForCategory('Totally Made Up'), 'Needs');
      expect(bucketForCategory(null), 'Needs');
      expect(bucketForCategory(''), 'Needs');
    });

    test('only ever returns a real budget bucket', () {
      for (final c in kExpenseCategories) {
        expect(kBudgetBuckets, contains(bucketForCategory(c)));
      }
    });

    test('every expense category is mapped explicitly except Other', () {
      final unmapped = kExpenseCategories
          .where((c) => !kCategoryToBucket.containsKey(c))
          .toList();
      expect(unmapped, ['Other']);
    });
  });

  group('non-expense buckets', () {
    test('savings jars are flagged and fed by no category', () {
      for (final b in kNonExpenseBuckets) {
        expect(isNonExpenseBucket(b), isTrue);
        expect(categoriesForBucket(b), isEmpty);
      }
      expect(isNonExpenseBucket('Needs'), isFalse);
    });
  });

  group('periodWindow', () {
    test('monthly window is [1st, 1st-of-next-month)', () {
      final w = periodWindow(DateTime.utc(2026, 3));
      expect(w.start, DateTime.utc(2026, 3));
      expect(w.end, DateTime.utc(2026, 4));
    });

    test('clamps at month end via day 1 of the next month', () {
      final w = periodWindow(DateTime.utc(2026, 1, 31));
      expect(w.end.isAfter(DateTime.utc(2026, 2, 28)), isTrue);
    });

    test('weekly and yearly', () {
      expect(periodWindow(DateTime.utc(2026, 3), 'weekly').end,
          DateTime.utc(2026, 3, 8));
      expect(periodWindow(DateTime.utc(2026, 3), 'yearly').end,
          DateTime.utc(2027, 3));
    });
  });

  group('deriveSpent', () {
    test('sums expenses for the bucket inside the period', () {
      final txns = [
        _txn('Rent', '20000', DateTime.utc(2026, 3, 3)),
        _txn('Food & Dining', '3000', DateTime.utc(2026, 3, 10)),
        _txn('Entertainment', '1500', DateTime.utc(2026, 3, 12)),
      ];
      expect(
        deriveSpent(txns, 'Needs', DateTime.utc(2026, 3)),
        Decimal.parse('23000'),
      );
      expect(
        deriveSpent(txns, 'Play', DateTime.utc(2026, 3)),
        Decimal.parse('1500'),
      );
    });

    test('ignores income and out-of-period rows', () {
      final txns = [
        _txn('Salary', '90000', DateTime.utc(2026, 3, 2), type: 'income'),
        _txn('Rent', '20000', DateTime.utc(2026, 3, 3)),
        _txn('Rent', '999', DateTime.utc(2026, 2, 2)),
      ];
      expect(
        deriveSpent(txns, 'Needs', DateTime.utc(2026, 3)),
        Decimal.parse('20000'),
      );
      expect(
        deriveSpent(txns, 'Needs', DateTime.utc(2026, 2)),
        Decimal.parse('999'),
      );
    });

    test('half-open: the last instant of the month is out', () {
      final edge = [_txn('Rent', '100', DateTime.utc(2026, 4))];
      expect(
        deriveSpent(edge, 'Needs', DateTime.utc(2026, 3)),
        Decimal.zero,
      );
      expect(
        deriveSpent(edge, 'Needs', DateTime.utc(2026, 4)),
        Decimal.parse('100'),
      );
    });

    test('a non-expense bucket derives zero', () {
      final txns = [_txn('Rent', '20000', DateTime.utc(2026, 3, 3))];
      expect(deriveSpent(txns, 'Giving', DateTime.utc(2026, 3)), Decimal.zero);
    });
  });
}
