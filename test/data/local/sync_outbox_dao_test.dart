import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SyncOutboxDao dao;

  setUp(() {
    db = AppDatabase.forTesting();
    dao = db.syncOutboxDao;
  });
  tearDown(() => db.close());

  Future<void> enqueue(String mid, {String tenant = 't1'}) => dao.enqueue(
    mutationId: mid,
    tenantId: tenant,
    operation: OutboxOperation.createTransaction,
    entityLocalId: 'txn-$mid',
    payload: {'type': 'expense', 'amount': '10.00'},
  );

  test('enqueue + pendingBatch returns oldest first', () async {
    await enqueue('a');
    await enqueue('b');
    await enqueue('c');

    final batch = await dao.pendingBatch();
    expect(batch.map((e) => e.mutationId), ['a', 'b', 'c']);
    expect(batch.first.operation, OutboxOperation.createTransaction);
    expect(batch.first.payload, contains('"amount":"10.00"'));
    expect(await dao.countPending(), 3);
  });

  test('mutationId is unique', () async {
    await enqueue('dup');
    expect(() => enqueue('dup'), throwsA(isA<Exception>()));
  });

  test('markInFlight counts the attempt; markRetry re-queues it', () async {
    await enqueue('x');
    final entry = (await dao.pendingBatch()).single;

    await dao.markInFlight(entry.id);
    var reread = await dao.byMutationId('x');
    expect(reread!.status, OutboxStatus.inFlight);
    expect(reread.attempts, 1);
    expect(reread.lastAttemptAt, isNotNull);
    expect(await dao.countPending(), 0);

    await dao.markRetry(entry.id, 'network down');
    reread = await dao.byMutationId('x');
    expect(reread!.status, OutboxStatus.pending);
    expect(reread.lastError, 'network down');
    expect(reread.attempts, 1); // not re-counted until the next markInFlight
    expect(await dao.countPending(), 1);
  });

  test('markSynced removes the entry', () async {
    await enqueue('done');
    final entry = (await dao.pendingBatch()).single;
    await dao.markSynced(entry.id);
    expect(await dao.byMutationId('done'), isNull);
  });

  test('markFailed parks it; requeueFailed brings it back', () async {
    await enqueue('bad');
    final entry = (await dao.pendingBatch()).single;

    await dao.markInFlight(entry.id);
    await dao.markFailed(entry.id, 'validation: amount required');
    expect((await dao.byMutationId('bad'))!.status, OutboxStatus.failed);
    expect(await dao.pendingBatch(), isEmpty);

    await dao.requeueFailed();
    expect(await dao.countPending(), 1);
  });

  test('clearForTenant only clears that workspace', () async {
    await enqueue('t1a');
    await enqueue('t2a', tenant: 't2');
    await dao.clearForTenant('t1');
    final left = await dao.pendingBatch();
    expect(left.map((e) => e.mutationId), ['t2a']);
  });
}
