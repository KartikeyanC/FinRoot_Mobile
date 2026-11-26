import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/export/application/export_loader.dart';
import 'package:finroot_mobile/features/export/data/export_transactions_source.dart';
import 'package:finroot_mobile/features/transactions/data/transactions_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

Map<String, dynamic> _row(String id, DateTime at, {String amount = '10'}) => {
  'id': id,
  'tenant_id': 't1',
  'type': 'expense',
  'amount': amount,
  'currency': 'INR',
  'category': 'Food',
  'description': null,
  'occurred_at': at.toUtc().toIso8601String(),
  'updated_at': at.toUtc().toIso8601String(),
};

/// A fake server holding [rows] (already oldest first), paging like PostgREST.
class _FakeServer {
  _FakeServer(this.rows);
  final List<Map<String, dynamic>> rows;
  final calls = <(int, int)>[];
  Object? error;

  Future<List<Map<String, dynamic>>> fetch({
    required String tenantId,
    required DateTime from,
    required DateTime toExclusive,
    required int offset,
    required int limit,
  }) async {
    calls.add((offset, limit));
    if (error != null) throw error!;
    return rows.skip(offset).take(limit).toList();
  }
}

void main() {
  final now = DateTime(2026, 11, 26, 12);

  group('ServerExportSource', () {
    test('pages 1000 rows at a time until a short page', () async {
      final base = DateTime.utc(2020);
      final server = _FakeServer([
        for (var i = 0; i < 2500; i++)
          _row('r$i', base.add(Duration(hours: i))),
      ]);
      final source = ServerExportSource(server.fetch);

      final rows = await source.fetchBetween(
        't1',
        from: DateTime(1970),
        toExclusive: DateTime(2030),
      );

      expect(rows, hasLength(2500));
      expect(server.calls, [(0, 1000), (1000, 1000), (2000, 1000)]);
      expect(rows.first.id, 'r0');
      expect(rows.first.amount.amount, Decimal.parse('10'));
    });

    test('an exact multiple of the page size asks once more', () async {
      final server = _FakeServer([
        for (var i = 0; i < 4; i++) _row('r$i', DateTime.utc(2020, 1, i + 1)),
      ]);
      final rows = await ServerExportSource(
        server.fetch,
        pageSize: 2,
      ).fetchBetween('t1', from: DateTime(1970), toExclusive: DateTime(2030));
      expect(rows, hasLength(4));
      expect(server.calls.length, 3);
    });

    test('unreadable rows are skipped; errors map to a Failure', () async {
      final server = _FakeServer([
        _row('ok', DateTime.utc(2020)),
        {'id': 'bad', 'type': 'nonsense'},
      ]);
      final source = ServerExportSource(server.fetch);
      final rows = await source.fetchBetween(
        't1',
        from: DateTime(1970),
        toExclusive: DateTime(2030),
      );
      expect(rows.map((t) => t.id), ['ok']);

      server.error = const SocketException('down');
      expect(
        source.fetchBetween(
          't1',
          from: DateTime(1970),
          toExclusive: DateTime(2030),
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('ExportLoader', () {
    late AppDatabase db;
    late TransactionsRepository cache;

    setUp(() {
      db = AppDatabase.forTesting();
      cache = TransactionsRepository(db);
    });
    tearDown(() => db.close());

    Future<void> insertLocal(
      String id,
      DateTime at, {
      LocalSyncStatus status = LocalSyncStatus.synced,
      String amount = '10.00',
    }) => db
        .into(db.localTransactions)
        .insert(
          LocalTransactionsCompanion.insert(
            id: id,
            tenantId: 't1',
            type: 'expense',
            amount: Decimal.parse(amount),
            category: 'Food',
            occurredAt: at,
            syncStatus: Value(status),
          ),
        );

    ExportLoader loader(_FakeServer server, {bool online = true}) =>
        ExportLoader(
          cache: cache,
          server: ServerExportSource(server.fetch),
          isOnline: () => online,
          now: () => now,
        );

    test('a range the cache covers never asks the server', () async {
      await insertLocal('local', DateTime(2026, 11, 10));
      final server = _FakeServer(const []);

      final out = await loader(server).load(
        't1',
        from: DateTime(2026, 11),
        toExclusive: DateTime(2026, 11, 27),
      );

      expect(out.rows.map((t) => t.id), ['local']);
      expect(out.phoneOnly, isFalse);
      expect(server.calls, isEmpty);
    });

    test(
      'All time online reads the server and keeps unsent local edits',
      () async {
        await insertLocal('old-cached', DateTime(2026, 10));
        await insertLocal(
          'edited',
          DateTime(2026, 10, 2),
          status: LocalSyncStatus.pendingUpdate,
          amount: '99.00',
        );
        await insertLocal(
          'new',
          DateTime(2026, 11, 20),
          status: LocalSyncStatus.pendingCreate,
        );
        final server = _FakeServer([
          _row('ancient', DateTime.utc(2021, 3)),
          _row('old-cached', DateTime(2026, 10)),
          _row('edited', DateTime(2026, 10, 2), amount: '5'),
        ]);

        final out = await loader(server)
            .load('t1', from: DateTime(1970), toExclusive: DateTime(2028));

        expect(out.phoneOnly, isFalse);
        expect(out.rows.map((t) => t.id), [
          'ancient',
          'old-cached',
          'edited',
          'new',
        ]);
        expect(
          out.rows.firstWhere((t) => t.id == 'edited').amount.amount,
          Decimal.parse('99'),
        );
        expect(server.calls, isNotEmpty);
      },
    );

    test('a row deleted on the phone but not yet sent is left out', () async {
      await insertLocal(
        'gone',
        DateTime(2026, 10),
        status: LocalSyncStatus.pendingDelete,
      );
      final server = _FakeServer([
        _row('gone', DateTime(2026, 10)),
        _row('kept', DateTime(2026, 10, 3)),
      ]);

      final out = await loader(server)
          .load('t1', from: DateTime(1970), toExclusive: DateTime(2028));

      expect(out.rows.map((t) => t.id), ['kept']);
    });

    test('offline falls back to the cache and flags it', () async {
      await insertLocal('local', DateTime(2026, 10));
      final server = _FakeServer([_row('ancient', DateTime.utc(2021))]);

      final out = await loader(
        server,
        online: false,
      ).load('t1', from: DateTime(1970), toExclusive: DateTime(2028));

      expect(out.phoneOnly, isTrue);
      expect(out.rows.map((t) => t.id), ['local']);
      expect(server.calls, isEmpty);
    });

    test('a network error mid-fetch also falls back to the cache', () async {
      await insertLocal('local', DateTime(2026, 10));
      final server = _FakeServer(const [])
        ..error = const SocketException('lost');

      final out = await loader(server)
          .load('t1', from: DateTime(1970), toExclusive: DateTime(2028));

      expect(out.phoneOnly, isTrue);
      expect(out.rows.map((t) => t.id), ['local']);
    });

    test('a server refusal is not hidden behind the cache', () async {
      final server = _FakeServer(const [])
        ..error = const PostgrestException(message: 'denied', code: '42501');

      expect(
        loader(server)
            .load('t1', from: DateTime(1970), toExclusive: DateTime(2028)),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });
}
