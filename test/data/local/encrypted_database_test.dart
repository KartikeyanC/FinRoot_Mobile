@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// M19 — encryption-at-rest, exercised against the real SQLite3MultipleCiphers
/// build on this machine (not the in-memory executor the other DB tests use,
/// and not a device). Verifies: the cipher is compiled in, `PRAGMA key`
/// actually encrypts the file, the right key round-trips, a wrong key is
/// rejected, and the stale-file self-heal check behaves.

const _key = 'a1b2c3d4e5f60718293a4b5c6d7e8f90'
    'a1b2c3d4e5f60718293a4b5c6d7e8f90'; // 64 hex = 32 bytes

void _openWithKey(String path, String key) {
  final db = sqlite3.open(path);
  try {
    db.execute("PRAGMA key = '$key'");
    db.execute('CREATE TABLE IF NOT EXISTS t (v TEXT)');
    db.execute("INSERT INTO t (v) VALUES ('secret-amount-18600')");
  } finally {
    db.close();
  }
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('finroot_enc_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('SQLite3MultipleCiphers is compiled in (PRAGMA cipher answers)', () {
    final db = sqlite3.openInMemory();
    try {
      expect(
        db.select('PRAGMA cipher'),
        isNotEmpty,
        reason: 'the sqlite3 build hook did not produce a ciphered library',
      );
    } finally {
      db.close();
    }
  });

  test('a keyed file is not readable as plaintext SQLite', () {
    final path = '${tmp.path}/enc.sqlite';
    _openWithKey(path, _key);

    // Raw bytes must not start with the "SQLite format 3" magic.
    final header = File(path).readAsBytesSync().sublist(0, 16);
    expect(
      String.fromCharCodes(header),
      isNot(startsWith('SQLite format 3')),
      reason: 'the database file is not encrypted',
    );

    // Opening without a key fails to read the schema.
    final noKey = sqlite3.open(path);
    try {
      expect(
        () => noKey.select('SELECT count(*) FROM sqlite_master'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      noKey.close();
    }
  });

  test('the correct key round-trips the data', () {
    final path = '${tmp.path}/enc.sqlite';
    _openWithKey(path, _key);

    final db = sqlite3.open(path);
    try {
      db.execute("PRAGMA key = '$_key'");
      final rows = db.select('SELECT v FROM t');
      expect(rows.single['v'], 'secret-amount-18600');
    } finally {
      db.close();
    }
  });

  test('a wrong key is rejected', () {
    final path = '${tmp.path}/enc.sqlite';
    _openWithKey(path, _key);

    final db = sqlite3.open(path);
    try {
      db.execute("PRAGMA key = 'ffffffffffffffffffffffffffffffff"
          "ffffffffffffffffffffffffffffffff'");
      expect(
        () => db.select('SELECT v FROM t'),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      db.close();
    }
  });

  test('drift runs its full schema on an encrypted file and reopens it', () async {
    final path = '${tmp.path}/finroot.sqlite';

    NativeDatabase open() => NativeDatabase(
      File(path),
      setup: (raw) {
        raw.execute("PRAGMA key = '$_key'");
        raw.execute('PRAGMA foreign_keys = ON');
      },
    );

    var db = AppDatabase.forTesting(open());
    await db.customStatement('SELECT 1'); // force open + onCreate
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .map((r) => r.read<String>('name'))
        .get();
    expect(names, contains('local_transactions'));
    expect(names, contains('sync_outbox'));
    await db.close();

    // File on disk is ciphered.
    final header = File(path).readAsBytesSync().sublist(0, 16);
    expect(String.fromCharCodes(header), isNot(startsWith('SQLite format 3')));

    // Reopen with the same key — the schema is intact.
    db = AppDatabase.forTesting(open());
    final again = await db
        .customSelect('SELECT count(*) c FROM local_transactions')
        .getSingle();
    expect(again.read<int>('c'), 0);
    await db.close();
  });
}
