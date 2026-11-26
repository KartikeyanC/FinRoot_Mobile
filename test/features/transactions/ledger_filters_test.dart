import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/transactions/application/transactions_providers.dart';
import 'package:finroot_mobile/features/transactions/data/transactions_repository.dart';
import 'package:finroot_mobile/features/transactions/domain/ledger_range.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LedgerRange', () {
    final now = DateTime(2026, 11, 26, 15, 30);

    test('presets resolve to [from, toExclusive)', () {
      final m = LedgerRange.preset(LedgerRangePreset.thisMonth, now);
      expect(m.from, DateTime(2026, 11));
      expect(m.toExclusive, DateTime(2026, 11, 27));

      final last = LedgerRange.preset(LedgerRangePreset.lastMonth, now);
      expect(last.from, DateTime(2026, 10));
      expect(last.toExclusive, DateTime(2026, 11));

      final d30 = LedgerRange.preset(LedgerRangePreset.last30Days, now);
      expect(d30.from, DateTime(2026, 10, 28));
      expect(d30.toExclusive, DateTime(2026, 11, 27));

      final y = LedgerRange.preset(LedgerRangePreset.thisYear, now);
      expect(y.from, DateTime(2026));
      expect(y.label, 'This year');
    });

    test('last month in January is December of the year before', () {
      final r = LedgerRange.preset(
        LedgerRangePreset.lastMonth,
        DateTime(2027, 1, 10),
      );
      expect(r.from, DateTime(2026, 12));
      expect(r.toExclusive, DateTime(2027));
    });

    test('custom covers whole days and labels itself', () {
      final r = LedgerRange.custom(
        DateTime(2026, 3, 5, 18),
        DateTime(2026, 4, 12, 9),
      );
      expect(r.from, DateTime(2026, 3, 5));
      expect(r.toExclusive, DateTime(2026, 4, 13));
      expect(r.lastDay, DateTime(2026, 4, 12));
      expect(r.label, '5 Mar – 12 Apr 2026');
      expect(
        LedgerRange.custom(DateTime(2025, 12, 30), DateTime(2026, 1, 2)).label,
        '30 Dec 2025 – 2 Jan 2026',
      );
    });

    test('startsBeforeCache compares against the 180-day window', () {
      expect(startsBeforeCache(DateTime(2026, 11), now), isFalse);
      expect(
        startsBeforeCache(now.subtract(const Duration(days: 181)), now),
        isTrue,
      );
      expect(startsBeforeCache(DateTime(2026), now), isTrue);
    });
  });

  group('LedgerFilterNotifier', () {
    test('range and categories count as active; clear resets', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(ledgerFilterProvider.notifier);

      expect(c.read(ledgerFilterProvider).isActive, isFalse);
      n.setRange(
        LedgerRange.preset(LedgerRangePreset.thisMonth, DateTime(2026, 11, 3)),
      );
      expect(c.read(ledgerFilterProvider).isActive, isTrue);
      n.setCategories({'Food', 'Fuel'});
      n.removeCategory('Food');
      expect(c.read(ledgerFilterProvider).categories, {'Fuel'});
      n.setType(null);
      expect(c.read(ledgerFilterProvider).range, isNotNull);
      n.clear();
      expect(c.read(ledgerFilterProvider).hasRangeOrCategory, isFalse);
    });
  });

  group('watchLedger date + category', () {
    late AppDatabase db;
    late TransactionsRepository repo;

    setUp(() {
      db = AppDatabase.forTesting();
      repo = TransactionsRepository(db);
    });
    tearDown(() => db.close());

    Future<void> insert(String id, DateTime at, String category) => db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: id,
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('10.00'),
            category: category,
            occurredAt: at,
            description: const Value(null),
          ),
        );

    test('occurredAt range is [from, toExclusive)', () async {
      await insert('before', DateTime(2026, 9, 30, 23), 'Food');
      await insert('start', DateTime(2026, 10), 'Food');
      await insert('end', DateTime(2026, 10, 31, 23, 59), 'Food');
      await insert('after', DateTime(2026, 11), 'Food');

      final rows = await repo
          .watchLedger(
            't1',
            from: DateTime(2026, 10),
            toExclusive: DateTime(2026, 11),
          )
          .first;
      expect(rows.map((t) => t.id), ['end', 'start']);
    });

    test('categories match any of the chosen ones', () async {
      await insert('a', DateTime(2026, 10), 'Food');
      await insert('b', DateTime(2026, 10, 2), 'Fuel');
      await insert('c', DateTime(2026, 10, 3), 'Rent');

      final rows = await repo
          .watchLedger('t1', categories: {'Food', 'Rent'})
          .first;
      expect(rows.map((t) => t.id), ['c', 'a']);
      expect(
        (await repo.watchLedger('t1', categories: const {}).first).length,
        3,
      );
    });

    test('watchCategories lists distinct categories A–Z', () async {
      await insert('a', DateTime(2026, 10), 'Rent');
      await insert('b', DateTime(2026, 10, 2), 'Food');
      await insert('c', DateTime(2026, 10, 3), 'Food');

      expect(await repo.watchCategories('t1').first, ['Food', 'Rent']);
    });
  });
}
