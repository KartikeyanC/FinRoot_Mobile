// The generated part (`app_database.g.dart`) resolves converter and enum types
// against this library's imports, so `decimal`, `converters` and `sync_enums`
// are imported here even though this file names nothing from them directly.
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import 'converters.dart';
import 'daos/sync_outbox_dao.dart';
import 'daos/sync_state_dao.dart';
import 'encrypted_connection.dart';
import 'sync_enums.dart';
import 'tables.dart';

export 'daos/sync_outbox_dao.dart';
export 'daos/sync_state_dao.dart';
export 'sync_enums.dart';
export 'tables.dart';

part 'app_database.g.dart';

/// The on-device database (M1 audit §12).
///
/// A cache, not a source of truth. Tables mirror a subset of the Supabase
/// project plus the sync outbox and per-entity cursors. Money never gets
/// recomputed here (ADR-0006) — the typed amount columns hold exactly what the
/// server sent, as strings.
///
/// Schema changes: bump [schemaVersion], add a step to [migration], and dump a
/// schema snapshot (`dart run drift_dev schema dump lib/data/local/app_database.dart
/// drift_schemas/`) so `drift_dev schema steps` / tests can verify the upgrade.
@DriftDatabase(
  tables: [
    LocalTransactions,
    LocalAccounts,
    LocalTrackers,
    LocalBudgets,
    LocalGoals,
    SyncOutbox,
    SyncStates,
    KvCache,
  ],
  daos: [SyncOutboxDao, SyncStateDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  /// Production: an encrypted on-device file.
  factory AppDatabase.encrypted() => AppDatabase._(openEncryptedDatabase());

  /// Tests: an in-memory database, no encryption, no file.
  factory AppDatabase.forTesting([QueryExecutor? executor]) =>
      AppDatabase._(executor ?? inMemoryExecutor());

  @override
  int get schemaVersion => 1;

  /// Dates are stored as ISO-8601 text, not unix seconds — it round-trips
  /// cleanly with the server's `timestamptz` values.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 is the first schema. Future versions add `if (from < N) { ... }`
      // steps here, each with a matching snapshot under drift_schemas/.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
