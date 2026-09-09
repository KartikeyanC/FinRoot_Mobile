import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../sync/data/row_mappers.dart';
import '../domain/account.dart';

/// Read-only access to the cached accounts (M4). M7's Transfer picker needs the
/// list; M8 builds account management on top of this and adds the write paths.
class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  /// All accounts for [tenantId], A→Z by name.
  Stream<List<AccountEntity>> watchAll(String tenantId) {
    final query = _db.select(_db.localAccounts)
      ..where((a) => a.tenantId.equals(tenantId))
      ..orderBy([
        (a) => OrderingTerm(expression: a.name.lower()),
      ]);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  /// Fold a server `accounts` row (as PostgREST returns it) into the cache —
  /// used right after an online create / edit so the change shows before the
  /// next sync pull confirms it.
  Future<void> cacheServerRow(Map<String, dynamic> row) {
    return _db
        .into(_db.localAccounts)
        .insertOnConflictUpdate(RowMappers.account(row));
  }

  Future<void> removeFromCache(String id) {
    return (_db.delete(_db.localAccounts)..where((a) => a.id.equals(id))).go();
  }

  AccountEntity _toEntity(LocalAccountRow r) {
    return AccountEntity(
      id: r.id,
      name: r.name,
      type: r.type,
      openingBalance: r.openingBalance == null
          ? null
          : Money(r.openingBalance!),
      color: r.color,
      icon: r.icon,
    );
  }
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(appDatabaseProvider)),
  name: 'accountsRepository',
);
