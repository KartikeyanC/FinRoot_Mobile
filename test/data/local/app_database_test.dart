import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting());
  tearDown(() => db.close());

  test('onCreate builds every table', () async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name != 'sqlite_sequence'",
        )
        .map((r) => r.read<String>('name'))
        .get();
    expect(
      names,
      containsAll([
        'local_transactions',
        'local_accounts',
        'local_trackers',
        'local_budgets',
        'local_goals',
        'sync_outbox',
        'sync_states',
        'kv_cache',
      ]),
    );
  });

  test('a transaction round-trips with an exact Decimal amount', () async {
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 'txn-1',
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('18600.00'),
            category: 'Labour',
            occurredAt: DateTime.utc(2026, 9, 8, 10, 30),
            description: const Value('Labour salary'),
            trackerId: const Value('trk-home'),
          ),
        );

    final row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('txn-1'))).getSingle();

    // Exact — not 18600.0 as a double would risk.
    expect(row.amount, Decimal.parse('18600.00'));
    // Stored numeric(14,2)-shaped, matching the server column and
    // Money.toStorageString().
    final stored = await db
        .customSelect(
          "SELECT amount FROM local_transactions WHERE id = 'txn-1'",
        )
        .getSingle();
    expect(stored.read<String>('amount'), '18600.00');
    expect(row.currency, 'INR'); // column default
    expect(row.syncStatus, LocalSyncStatus.synced); // column default
    expect(row.trackerId, 'trk-home');
    expect(row.occurredAt, DateTime.utc(2026, 9, 8, 10, 30));
  });

  test('DateTime is stored as ISO text (server timestamptz interop)', () async {
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 'txn-2',
            tenantId: 't1',
            type: 'income',
            amount: Decimal.parse('75000.00'),
            category: 'Salary',
            occurredAt: DateTime.utc(2026, 9, 3, 8),
          ),
        );
    final raw = await db
        .customSelect(
          "SELECT occurred_at FROM local_transactions WHERE id = 'txn-2'",
        )
        .getSingle();
    expect(raw.read<String>('occurred_at'), startsWith('2026-09-03'));
  });

  test('kv_cache is keyed by (scope, key)', () async {
    await db
        .into(db.kvCache)
        .insert(
          KvCacheCompanion.insert(
            scope: 't1',
            key: 'menus',
            value: '["budget"]',
          ),
        );
    await db
        .into(db.kvCache)
        .insertOnConflictUpdate(
          KvCacheCompanion.insert(
            scope: 't1',
            key: 'menus',
            value: '["budget","goals"]',
          ),
        );
    final row = await (db.select(
      db.kvCache,
    )..where((t) => t.scope.equals('t1') & t.key.equals('menus'))).getSingle();
    expect(row.value, '["budget","goals"]');
  });
}
