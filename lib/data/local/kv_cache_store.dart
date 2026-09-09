import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_providers.dart';

/// Thin typed access to the `kv_cache` table (M4) — small JSON blobs that are
/// not worth their own table: `tenant_settings`, the effective-menus set, and
/// (M8) the last `dashboard_summary` roll-up so balances survive going offline.
class KvCacheStore {
  KvCacheStore(this._db);

  final AppDatabase _db;

  Future<String?> read(String scope, String key) async {
    final row =
        await (_db.select(_db.kvCache)
              ..where((t) => t.scope.equals(scope) & t.key.equals(key)))
            .getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String scope, String key, String value) {
    return _db
        .into(_db.kvCache)
        .insertOnConflictUpdate(
          KvCacheCompanion.insert(scope: scope, key: key, value: value),
        );
  }

  Future<void> delete(String scope, String key) {
    return (_db.delete(_db.kvCache)
          ..where((t) => t.scope.equals(scope) & t.key.equals(key)))
        .go();
  }
}

final kvCacheStoreProvider = Provider<KvCacheStore>(
  (ref) => KvCacheStore(ref.watch(appDatabaseProvider)),
  name: 'kvCacheStore',
);
