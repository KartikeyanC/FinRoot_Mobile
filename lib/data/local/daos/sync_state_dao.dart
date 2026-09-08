import 'package:drift/drift.dart';

import '../app_database.dart';

part 'sync_state_dao.g.dart';

/// Per-(entity, workspace) delta-pull bookmark. M5 reads `cursor` to ask the
/// server only for rows changed since the last pull.
@DriftAccessor(tables: [SyncStates])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  static String keyFor(String entity, String tenantId) => '$entity:$tenantId';

  Future<SyncStateRow?> forEntity(String entity, String tenantId) {
    return (select(
      syncStates,
    )..where((t) => t.key.equals(keyFor(entity, tenantId)))).getSingleOrNull();
  }

  /// Advance the delta cursor and stamp the pull time.
  Future<void> recordPull({
    required String entity,
    required String tenantId,
    required DateTime cursor,
    bool wasFullSync = false,
  }) {
    final now = DateTime.now().toUtc();
    return into(syncStates).insertOnConflictUpdate(
      SyncStatesCompanion.insert(
        key: keyFor(entity, tenantId),
        entity: entity,
        tenantId: tenantId,
        cursor: Value(cursor),
        lastPulledAt: Value(now),
        lastFullSyncAt: wasFullSync ? Value(now) : const Value.absent(),
      ),
    );
  }

  Future<void> reset(String entity, String tenantId) {
    return (delete(
      syncStates,
    )..where((t) => t.key.equals(keyFor(entity, tenantId)))).go();
  }

  Future<void> resetTenant(String tenantId) {
    return (delete(syncStates)..where((t) => t.tenantId.equals(tenantId))).go();
  }
}
