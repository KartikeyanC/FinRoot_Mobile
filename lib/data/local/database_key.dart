import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The 256-bit key that encrypts the local database.
///
/// Generated once with a CSPRNG, then kept in the platform keystore/keychain —
/// never derived from a password, never in source, never logged. On sign-out
/// `purgeSecureStorage()` deletes it along with the session; the now-unreadable
/// database file is recreated on the next sign-in
/// (`openEncryptedDatabase` self-heals).
class DatabaseKey {
  const DatabaseKey([this._storage = _defaultStorage]);

  final FlutterSecureStorage _storage;

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _storageKey = 'finroot.db.key';

  /// 64 hex chars = 32 bytes, the raw-key form `PRAGMA key` accepts.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && _isHex64(existing)) return existing;
    final fresh = _random32BytesHex();
    await _storage.write(key: _storageKey, value: fresh);
    return fresh;
  }

  Future<void> delete() => _storage.delete(key: _storageKey);

  static bool _isHex64(String s) =>
      s.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(s);

  static String _random32BytesHex() {
    final rng = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final databaseKeyProvider = Provider<DatabaseKey>(
  (ref) => const DatabaseKey(),
  name: 'databaseKey',
);
