import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/transactions/data/transactions_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = TransactionsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insertTxn({
    required String id,
    String tenant = 't1',
    String type = 'expense',
    String amount = '100.00',
    String currency = 'INR',
    String category = 'Food & Dining',
    String? description,
    required DateTime occurredAt,
    LocalSyncStatus status = LocalSyncStatus.synced,
  }) {
    return db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: id,
            tenantId: tenant,
            type: type,
            amount: Decimal.parse(amount),
            category: category,
            occurredAt: occurredAt,
            currency: Value(currency),
            description: Value(description),
            syncStatus: Value(status),
          ),
        );
  }

  test('watchRecent returns newest first, capped at the limit', () async {
    for (var day = 1; day <= 8; day++) {
      await insertTxn(id: 'txn-$day', occurredAt: DateTime.utc(2026, 9, day));
    }

    final recent = await repo.watchRecent('t1', limit: 3).first;

    expect(recent, hasLength(3));
    expect(recent.map((t) => t.id), ['txn-8', 'txn-7', 'txn-6']);
  });

  test('watchRecent scopes to the tenant', () async {
    await insertTxn(id: 'mine', occurredAt: DateTime.utc(2026, 9, 5));
    await insertTxn(
      id: 'theirs',
      tenant: 't2',
      occurredAt: DateTime.utc(2026, 9, 6),
    );

    final recent = await repo.watchRecent('t1').first;

    expect(recent.map((t) => t.id), ['mine']);
  });

  test('watchRecent excludes rows deleted offline (pendingDelete)', () async {
    await insertTxn(id: 'live', occurredAt: DateTime.utc(2026, 9, 5));
    await insertTxn(
      id: 'gone',
      occurredAt: DateTime.utc(2026, 9, 6),
      status: LocalSyncStatus.pendingDelete,
    );

    final recent = await repo.watchRecent('t1').first;

    expect(recent.map((t) => t.id), ['live']);
  });

  test('watchRecent maps type, exact amount and sync state', () async {
    await insertTxn(
      id: 'txn',
      type: 'income',
      amount: '75000.50',
      category: 'Salary',
      description: 'August pay',
      occurredAt: DateTime.utc(2026, 9, 2),
      status: LocalSyncStatus.pendingCreate,
    );

    final txn = (await repo.watchRecent('t1').first).single;

    expect(txn.type, TxnType.income);
    expect(txn.amount.amount, Decimal.parse('75000.50'));
    expect(txn.amount.currency, 'INR');
    expect(txn.title, 'August pay'); // note wins over category
    expect(txn.isPending, isTrue);
    expect(txn.hasFailedSync, isFalse);
  });

  test('watchRecent is live — a new row pushes an update', () async {
    await insertTxn(id: 'first', occurredAt: DateTime.utc(2026, 9, 2));

    final emissions = <int>[];
    final sub = repo.watchRecent('t1').listen((rows) => emissions.add(rows.length));
    await Future<void>.delayed(Duration.zero);

    await insertTxn(id: 'second', occurredAt: DateTime.utc(2026, 9, 2));
    await Future<void>.delayed(Duration.zero);

    await sub.cancel();
    expect(emissions, [1, 2]);
  });

  group('watchCountSince', () {
    test('counts records on or after the cutoff, tenant-scoped', () async {
      await insertTxn(id: 'old', occurredAt: DateTime.utc(2026, 7, 2));
      await insertTxn(id: 'in-1', occurredAt: DateTime.utc(2026, 8, 20));
      await insertTxn(id: 'in-2', occurredAt: DateTime.utc(2026, 9, 5));
      await insertTxn(
        id: 'other-tenant',
        tenant: 't2',
        occurredAt: DateTime.utc(2026, 9, 5),
      );

      final count =
          await repo.watchCountSince('t1', DateTime.utc(2026, 8, 11)).first;

      expect(count, 2);
    });

    test('ignores rows deleted offline', () async {
      await insertTxn(id: 'keep', occurredAt: DateTime.utc(2026, 9, 5));
      await insertTxn(
        id: 'drop',
        occurredAt: DateTime.utc(2026, 9, 6),
        status: LocalSyncStatus.pendingDelete,
      );

      final count =
          await repo.watchCountSince('t1', DateTime.utc(2026, 9, 2)).first;

      expect(count, 1);
    });
  });
}
