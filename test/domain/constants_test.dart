import 'package:finroot_mobile/domain/constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the value lists against the FinRoot web repo (see the file's own note).
void main() {
  test('expense categories match src/lib/finance.ts', () {
    expect(kExpenseCategories, [
      'Food & Dining',
      'Transport',
      'Shopping',
      'Healthcare',
      'Education',
      'Travel',
      'Subscriptions',
      'Utilities',
      'Rent',
      'Personal Care',
      'Entertainment',
      'Other',
    ]);
  });

  test('budget buckets match src/lib/finance.ts (7-bucket model)', () {
    expect(kBudgetBuckets.length, 7);
    expect(kBudgetBuckets.first, 'Needs');
    expect(kBudgetBuckets, contains('Agri'));
  });

  test('tracker types match src/lib/trackers.ts', () {
    expect(kTrackerTypes.first, 'Home Construction');
    expect(kTrackerTypes.last, 'Custom');
  });

  test('TxnType wire values are stable', () {
    expect(TxnType.expense.wire, 'expense');
    expect(TxnType.fromWire('transfer'), TxnType.transfer);
  });

  test('feature menu ids match all_feature_menus()', () {
    expect(FeatureMenu.billScan.id, 'bill-scan');
    expect(FeatureMenu.netWorth.id, 'net-worth');
    expect(FeatureMenu.trackers.id, 'trackers');
  });

  test('trackerDisplayLabel adds the T- prefix, never stored', () {
    expect(trackerDisplayLabel('Home Construction'), 'T-Home Construction');
    expect(trackerDisplayLabel('  Wedding  '), 'T-Wedding');
  });
}
