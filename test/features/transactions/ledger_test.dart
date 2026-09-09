import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/data/transactions_repository.dart';
import 'package:finroot_mobile/features/transactions/domain/day_group.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionEntity _t(String id, DateTime at) => TransactionEntity(
  id: id,
  type: TxnType.expense,
  amount: Money.zero(),
  category: 'Other',
  occurredAt: at,
);

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = TransactionsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert({
    required String id,
    String type = 'expense',
    String amount = '100.00',
    String category = 'Food & Dining',
    String? description,
    String? accountId,
    String? transferTo,
    String? trackerId,
    required DateTime occurredAt,
    LocalSyncStatus status = LocalSyncStatus.synced,
  }) {
    return db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: id,
            tenantId: 't1',
            type: type,
            amount: Decimal.parse(amount),
            category: category,
            occurredAt: occurredAt,
            description: Value(description),
            accountId: Value(accountId),
            transferToAccountId: Value(transferTo),
            trackerId: Value(trackerId),
            syncStatus: Value(status),
          ),
        );
  }

  test('watchLedger filters by type', () async {
    await insert(id: 'e', occurredAt: DateTime.utc(2026, 9, 5));
    await insert(id: 'i', type: 'income', occurredAt: DateTime.utc(2026, 9, 6));

    final expenses = await repo.watchLedger('t1', type: TxnType.expense).first;
    expect(expenses.map((t) => t.id), ['e']);
  });

  test('watchLedger searches note and category, case-insensitively', () async {
    await insert(
      id: 'a',
      category: 'Transport',
      description: 'Airport CAB',
      occurredAt: DateTime.utc(2026, 9, 5),
    );
    await insert(
      id: 'b',
      description: 'lunch',
      occurredAt: DateTime.utc(2026, 9, 6),
    );

    expect(
      (await repo.watchLedger('t1', search: 'cab').first).map((t) => t.id),
      ['a'],
    );
    expect(
      (await repo.watchLedger('t1', search: 'food').first).map((t) => t.id),
      ['b'],
    );
  });

  test('watchLedger by account matches either side of a transfer', () async {
    await insert(
      id: 'out',
      type: 'transfer',
      accountId: 'acc-a',
      transferTo: 'acc-b',
      occurredAt: DateTime.utc(2026, 9, 5),
    );
    await insert(
      id: 'spend',
      accountId: 'acc-b',
      occurredAt: DateTime.utc(2026, 9, 6),
    );
    await insert(
      id: 'other',
      accountId: 'acc-c',
      occurredAt: DateTime.utc(2026, 9, 7),
    );

    final forB = await repo.watchLedger('t1', accountId: 'acc-b').first;
    expect(forB.map((t) => t.id).toSet(), {'out', 'spend'});
  });

  test('watchLedger excludes pendingDelete rows', () async {
    await insert(id: 'live', occurredAt: DateTime.utc(2026, 9, 5));
    await insert(
      id: 'gone',
      occurredAt: DateTime.utc(2026, 9, 6),
      status: LocalSyncStatus.pendingDelete,
    );
    final all = await repo.watchLedger('t1').first;
    expect(all.map((t) => t.id), ['live']);
  });

  test('watchById is live and goes null when the row is removed', () async {
    await insert(id: 'x', occurredAt: DateTime.utc(2026, 9, 5));

    final seen = <bool>[];
    final sub = repo.watchById('x').listen((t) => seen.add(t != null));
    await Future<void>.delayed(Duration.zero);

    await (db.delete(db.localTransactions)..where((t) => t.id.equals('x'))).go();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [true, false]);
  });

  test('watchLedger by tracker returns only tagged rows', () async {
    await insert(id: 'in', trackerId: 'trk-1', occurredAt: DateTime.utc(2026, 9, 5));
    await insert(id: 'out', occurredAt: DateTime.utc(2026, 9, 6));

    final tagged = await repo.watchLedger('t1', trackerId: 'trk-1').first;
    expect(tagged.map((t) => t.id), ['in']);
  });

  group('watchUntaggedInWindow', () {
    test('untagged non-transfer rows inside [from, toExclusive)', () async {
      await insert(id: 'early', occurredAt: DateTime.utc(2026, 2, 20));
      await insert(id: 'in', occurredAt: DateTime.utc(2026, 3, 10));
      await insert(
        id: 'tagged',
        trackerId: 'trk-x',
        occurredAt: DateTime.utc(2026, 3, 11),
      );
      await insert(
        id: 'xfer',
        type: 'transfer',
        occurredAt: DateTime.utc(2026, 3, 12),
      );
      await insert(id: 'late', occurredAt: DateTime.utc(2026, 7, 2));

      final pool = await repo
          .watchUntaggedInWindow(
            't1',
            from: DateTime.utc(2026, 3),
            toExclusive: DateTime.utc(2026, 7),
          )
          .first;
      expect(pool.map((t) => t.id), ['in']);
    });
  });

  test('setTrackerIdLocally tags and clears cache rows', () async {
    await insert(id: 'a', occurredAt: DateTime.utc(2026, 9, 5));
    await insert(id: 'b', occurredAt: DateTime.utc(2026, 9, 6));

    await repo.setTrackerIdLocally(['a', 'b'], 'trk-9');
    final rows = await db.select(db.localTransactions).get();
    expect(rows.every((r) => r.trackerId == 'trk-9'), isTrue);

    await repo.setTrackerIdLocally(['a'], null);
    final a = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('a'))).getSingle();
    expect(a.trackerId, isNull);
  });

  test('groupByDay splits a newest-first list into newest-first day groups', () {
    final rows = [
      _t('a', DateTime(2026, 9, 8, 20)),
      _t('b', DateTime(2026, 9, 8, 9)),
      _t('c', DateTime(2026, 9, 7, 12)),
    ];
    final groups = groupByDay(rows);
    expect(groups, hasLength(2));
    expect(groups[0].items.map((t) => t.id), ['a', 'b']);
    expect(groups[1].items.map((t) => t.id), ['c']);
  });
}
