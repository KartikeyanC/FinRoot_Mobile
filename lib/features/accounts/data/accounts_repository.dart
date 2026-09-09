import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
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
