import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/sync/application/delta_puller.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:flutter_test/flutter_test.dart';

import '_fakes.dart';

void main() {
  late AppDatabase db;
  late FakePullGateway gateway;
  late DeltaPuller puller;

  setUp(() {
    db = AppDatabase.forTesting();
    gateway = FakePullGateway();
    puller = DeltaPuller(db, gateway);
  });
  tearDown(() => db.close());

  Future<int> cachedTxnCount() async {
    final r = await db
        .customSelect('SELECT count(*) c FROM local_transactions')
        .getSingle();
    return r.read<int>('c');
  }

  test(
    'delta pull inserts server rows as synced and advances the cursor',
    () async {
      gateway.rows[SyncEntity.transaction]!.addAll([
        serverTxn(
          id: 'a',
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 10),
        ),
        serverTxn(
          id: 'b',
          tenant: 't1',
          updatedAt: DateTime.utc(2026, 9, 8, 11),
        ),
      ]);

      final r = await puller.run('t1');

      expect(r.rowsApplied, 2);
      final a = await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('a'))).getSingle();
      expect(a.syncStatus, LocalSyncStatus.synced);
      expect(a.serverUpdatedAt, isNotNull);

      final state = await db.syncStateDao.forEntity('transaction', 't1');
      expect(state!.cursor, DateTime.utc(2026, 9, 8, 11));
    },
  );

  test('a row with a pending local edit is not overwritten', () async {
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 'x',
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('99.00'),
            category: 'MyLocalEdit',
            occurredAt: DateTime.utc(2026, 9, 8),
            syncStatus: const Value(LocalSyncStatus.pendingUpdate),
          ),
        );
    gateway.rows[SyncEntity.transaction]!.add(
      serverTxn(
        id: 'x',
        tenant: 't1',
        category: 'ServerVersion',
        updatedAt: DateTime.utc(2026, 9, 9, 9),
      ),
    );

    await puller.run('t1');

    final row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('x'))).getSingle();
    expect(row.category, 'MyLocalEdit'); // local wins until it is pushed
    expect(row.syncStatus, LocalSyncStatus.pendingUpdate);
    expect(
      row.serverUpdatedAt,
      DateTime.utc(2026, 9, 9, 9),
    ); // recorded for conflict check
  });

  test('full sync prunes a synced row the server no longer has', () async {
    // Two synced rows locally.
    for (final id in ['keep', 'stale']) {
      await db
          .into(db.localTransactions)
          .insert(
            LocalTransactionsCompanion.insert(
              id: id,
              tenantId: 't1',
              type: 'expense',
              amount: Decimal.parse('1.00'),
              category: 'Other',
              occurredAt: DateTime.utc(2026, 9, 8),
              syncStatus: const Value(LocalSyncStatus.synced),
            ),
          );
    }
    // A pending-create that the server does not know about yet.
    await db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: 'mine',
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse('2.00'),
            category: 'Other',
            occurredAt: DateTime.utc(2026, 9, 8),
            syncStatus: const Value(LocalSyncStatus.pendingCreate),
          ),
        );
    // The server only has 'keep'.
    gateway.rows[SyncEntity.transaction]!.add(
      serverTxn(
        id: 'keep',
        tenant: 't1',
        updatedAt: DateTime.utc(2026, 9, 8, 12),
      ),
    );

    await puller.run('t1', full: true);

    expect(await cachedTxnCount(), 2); // keep + mine
    expect(
      await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('stale'))).getSingleOrNull(),
      isNull,
    );
    expect(
      await (db.select(
        db.localTransactions,
      )..where((t) => t.id.equals('mine'))).getSingleOrNull(),
      isNotNull,
    );
  });

  test('a tombstoned tracker is removed from the cache', () async {
    await db
        .into(db.localTrackers)
        .insert(
          LocalTrackersCompanion.insert(
            id: 'trk-1',
            tenantId: 't1',
            name: 'Home Construction',
            type: 'Home Construction',
            startDate: DateTime.utc(2026, 3, 2),
            syncStatus: const Value(LocalSyncStatus.synced),
          ),
        );
    gateway.rows[SyncEntity.tracker]!.add({
      'id': 'trk-1',
      'tenant_id': 't1',
      'name': 'Home Construction',
      'type': 'Home Construction',
      'start_date': '2026-03-01',
      'end_date': null,
      'budget': null,
      'currency': 'INR',
      'description': null,
      'status': 'active',
      'deleted_at': '2026-09-09T00:00:00Z',
      'updated_at': '2026-09-09T00:00:00Z',
    });

    await puller.run('t1');

    expect(
      await (db.select(
        db.localTrackers,
      )..where((t) => t.id.equals('trk-1'))).getSingleOrNull(),
      isNull,
    );
  });
}
