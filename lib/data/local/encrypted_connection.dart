import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/logging/app_logger.dart';
import 'database_key.dart';

const _dbFileName = 'finroot.sqlite';

/// Opens the on-device database, encrypted with SQLite3MultipleCiphers.
///
/// Encryption is compiled in by the `hooks: user_defines: sqlite3: source:
/// sqlite3mc` block in pubspec.yaml (drift's current recommended path — the old
/// `sqlcipher_flutter_libs` route was dropped in drift 2.32). `PRAGMA key`
/// below turns it on; the app never touches an unencrypted database file.
///
/// ⚠️ Device verification pending — no Android SDK / iOS toolchain on the
/// build machine yet (M2 issue I-1). The schema and DAOs are exercised against
/// an in-memory database in tests.
LazyDatabase openEncryptedDatabase([DatabaseKey? keyProvider]) {
  final keys = keyProvider ?? const DatabaseKey();
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _dbFileName));
    final key = await keys.getOrCreate();

    // Self-heal the sign-out → new-key case: on sign-out the key is purged, so
    // an existing file can no longer be opened. Rather than crash on every
    // launch, detect it once and start fresh. (No data loss that matters — the
    // file is a cache; the server is the source of truth.)
    if (await file.exists() && !_canOpenWithKey(file.path, key)) {
      AppLog.of('db').warning('stale encrypted database — recreating');
      await file.delete();
    }

    return NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        assert(
          _hasCipher(raw),
          'SQLite3MultipleCiphers is not loaded. Check the pubspec `hooks` '
          'block and that the platform build ran the sqlite3 build hook.',
        );
        raw.execute("PRAGMA key = '${_escapeSingleQuotes(key)}'");
        raw.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}

/// In-memory database for tests — no encryption, no file, no key.
QueryExecutor inMemoryExecutor() => NativeDatabase.memory();

bool _canOpenWithKey(String path, String key) {
  try {
    final db = sqlite3.open(path);
    try {
      db.execute("PRAGMA key = '${_escapeSingleQuotes(key)}'");
      // Reading the schema fails with "file is not a database" on a wrong key.
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } finally {
      db.close();
    }
  } on Object {
    return false;
  }
}

bool _hasCipher(Database db) {
  try {
    // `PRAGMA cipher` is not an upstream-SQLite pragma; a non-empty result
    // means SQLite3MultipleCiphers is active.
    return db.select('PRAGMA cipher').isNotEmpty;
  } on Object {
    return false;
  }
}

String _escapeSingleQuotes(String s) => s.replaceAll("'", "''");

/// Deletes the database file. Called on a confirmed sign-out (wired in M5).
Future<void> deleteDatabaseFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, _dbFileName));
    if (await file.exists()) await file.delete();
  } on Object catch (e) {
    AppLog.of('db').warning('could not delete database file: ${e.runtimeType}');
  }
}
