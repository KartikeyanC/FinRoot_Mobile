import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/currency.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_spend.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the ported tracker fold against the FinRoot **web** repo's
/// `src/lib/trackers.test.ts` (single source of truth — ADR-0008).

TrackerEntity _tracker(
  String id, {
  String? budget,
  DateTime? start,
  DateTime? end,
  String status = 'active',
}) => TrackerEntity(
  id: id,
  name: 'Home Construction',
  type: 'Home Construction',
  startDate: start ?? DateTime.utc(2026, 1, 2),
  endDate: end,
  budget: budget == null ? null : Money.parse(budget),
  status: status,
);

TrackerSpendRow _row(
  String trackerId, {
  String type = 'expense',
  String currency = 'INR',
  String total = '0',
  int count = 0,
}) => TrackerSpendRow(
  trackerId: trackerId,
  type: type,
  currency: currency,
  total: Decimal.parse(total),
  count: count,
);

void main() {
  test('conserves money: every expense row lands on exactly one tracker', () {
    final trackers = [_tracker('a'), _tracker('b')];
    final rows = [
      _row('a', total: '18600', count: 1),
      _row('a', total: '12500', count: 1),
      _row('b', total: '4200', count: 3),
    ];
    final folded = foldTrackerSpend(trackers, rows);
    final total = folded.fold(
      Decimal.zero,
      (s, t) => s + t.spent.amount,
    );
    expect(total, Decimal.parse('35300'));
  });

  test('a row for an unknown tracker is dropped, not misattributed', () {
    final folded = foldTrackerSpend(
      [_tracker('a')],
      [_row('ghost', total: '9999', count: 1)],
    );
    expect(folded.single.spent.amount, Decimal.zero);
    expect(folded.single.txnCount, 0);
  });

  test('income is kept separate from spend, never netted', () {
    final folded = foldTrackerSpend(
      [_tracker('a')],
      [
        _row('a', total: '1000', count: 1),
        _row('a', type: 'income', total: '400', count: 1),
      ],
    );
    expect(folded.single.spent.amount, Decimal.parse('1000'));
    expect(folded.single.inflow.amount, Decimal.parse('400'));
  });

  test('transfers count in neither spend nor inflow', () {
    final folded = foldTrackerSpend(
      [_tracker('a')],
      [_row('a', type: 'transfer', total: '5000', count: 1)],
    );
    expect(folded.single.spent.amount, Decimal.zero);
    expect(folded.single.inflow.amount, Decimal.zero);
  });

  test('foreign-currency rows fold through the fixed FX table', () {
    final folded = foldTrackerSpend(
      [_tracker('a')],
      [_row('a', currency: 'AED', total: '1000', count: 1)],
    );
    expect(
      folded.single.spent.amount,
      Decimal.parse(toInr(1000, 'AED').toString()),
    );
  });

  test('null / empty rows → zeros, no budget → remaining null', () {
    for (final rows in [null, <TrackerSpendRow>[]]) {
      final f = foldTrackerSpend([_tracker('a')], rows).single;
      expect(f.spent.amount, Decimal.zero);
      expect(f.utilization, 0);
      expect(f.remaining, isNull);
      expect(f.hasBudget, isFalse);
    }
  });

  test('a zero budget is treated as no budget (absent != spent-in-full)', () {
    final f = foldTrackerSpend([_tracker('b', budget: '0')], []).single;
    expect(f.remaining, isNull);
    expect(f.utilization, 0);
  });

  test('utilization and remaining against a real budget', () {
    final f = foldTrackerSpend(
      [_tracker('a', budget: '4000000')],
      [_row('a', total: '284500', count: 12)],
    ).single;
    expect(f.utilization, 7); // 7.1% rounded
    expect(f.remaining!.amount, Decimal.parse('3715500'));
    expect(f.txnCount, 12);
  });

  test('remaining goes negative rather than lying about an overrun', () {
    final f = foldTrackerSpend(
      [_tracker('a', budget: '1000')],
      [_row('a', total: '1500', count: 1)],
    ).single;
    expect(f.remaining!.amount, Decimal.parse('-500'));
    expect(f.utilization, 150);
    expect(f.isOverBudget, isTrue);
  });

  group('isWithinTrackerWindow (metadata only — does not decide membership)', () {
    final t = _tracker(
      'a',
      start: DateTime.utc(2026, 3, 2),
      end: DateTime.utc(2026, 6, 30),
    );

    test('half-open [start, end]; the end date itself is inside', () {
      expect(isWithinTrackerWindow(DateTime.utc(2026, 2, 28), t), isFalse);
      expect(isWithinTrackerWindow(DateTime.utc(2026, 3, 2), t), isTrue);
      expect(isWithinTrackerWindow(DateTime.utc(2026, 6, 30, 23), t), isTrue);
      expect(isWithinTrackerWindow(DateTime.utc(2026, 7, 2), t), isFalse);
    });

    test('an open-ended tracker has no upper bound', () {
      final open = _tracker('o', start: DateTime.utc(2026, 3, 2));
      expect(isWithinTrackerWindow(DateTime.utc(2030, 1, 2), open), isTrue);
    });
  });
}
