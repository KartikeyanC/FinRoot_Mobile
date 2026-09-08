import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncStateDao dao;

  setUp(() {
    db = AppDatabase.forTesting();
    dao = db.syncStateDao;
  });
  tearDown(() => db.close());

  test('no state for an entity that was never pulled', () async {
    expect(await dao.forEntity('transaction', 't1'), isNull);
  });

  test('recordPull upserts the cursor and stamps the pull', () async {
    final c1 = DateTime.utc(2026, 9, 8, 12);
    await dao.recordPull(entity: 'transaction', tenantId: 't1', cursor: c1);

    var row = await dao.forEntity('transaction', 't1');
    expect(row!.cursor, c1);
    expect(row.lastPulledAt, isNotNull);
    expect(row.lastFullSyncAt, isNull);

    final c2 = DateTime.utc(2026, 9, 9, 9);
    await dao.recordPull(
      entity: 'transaction',
      tenantId: 't1',
      cursor: c2,
      wasFullSync: true,
    );
    row = await dao.forEntity('transaction', 't1');
    expect(row!.cursor, c2);
    expect(row.lastFullSyncAt, isNotNull);
  });

  test('a later non-full pull does not clear lastFullSyncAt', () async {
    await dao.recordPull(
      entity: 'transaction',
      tenantId: 't1',
      cursor: DateTime.utc(2026, 9, 8),
      wasFullSync: true,
    );
    await dao.recordPull(
      entity: 'transaction',
      tenantId: 't1',
      cursor: DateTime.utc(2026, 9, 9),
    );
    final row = await dao.forEntity('transaction', 't1');
    expect(row!.lastFullSyncAt, isNotNull);
  });

  test('state is per (entity, tenant)', () async {
    await dao.recordPull(
      entity: 'transaction',
      tenantId: 't1',
      cursor: DateTime.utc(2026, 1, 5, 6),
    );
    await dao.recordPull(
      entity: 'account',
      tenantId: 't1',
      cursor: DateTime.utc(2026, 2, 4, 7),
    );
    expect(
      (await dao.forEntity('transaction', 't1'))!.cursor,
      DateTime.utc(2026, 1, 5, 6),
    );
    expect(
      (await dao.forEntity('account', 't1'))!.cursor,
      DateTime.utc(2026, 2, 4, 7),
    );
    expect(await dao.forEntity('transaction', 't2'), isNull);

    await dao.resetTenant('t1');
    expect(await dao.forEntity('transaction', 't1'), isNull);
    expect(await dao.forEntity('account', 't1'), isNull);
  });
}
