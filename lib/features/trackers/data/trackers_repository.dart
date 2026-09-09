import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../sync/data/row_mappers.dart';
import '../domain/tracker.dart';

/// Reads trackers out of the local cache (M4), and (M9) folds a server row
/// back in after an online write. A cache the sync engine keeps fresh; tracker
/// spend stays server-derived (ADR-0006) — see `tracker_spend.dart`.
class TrackersRepository {
  TrackersRepository(this._db);

  final AppDatabase _db;

  /// Active trackers for [tenantId], most recently started first.
  Stream<List<TrackerEntity>> watchActive(String tenantId) =>
      watchAll(tenantId, statuses: const {'active'});

  /// Trackers for [tenantId], most recently started first. [statuses] narrows
  /// by lifecycle state; null = all.
  Stream<List<TrackerEntity>> watchAll(
    String tenantId, {
    Set<String>? statuses,
  }) {
    final query = _db.select(_db.localTrackers)
      ..where((t) {
        var cond = t.tenantId.equals(tenantId);
        if (statuses != null && statuses.isNotEmpty) {
          cond = cond & t.status.isIn(statuses);
        }
        return cond;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  Stream<TrackerEntity?> watchById(String id) {
    final query = _db.select(_db.localTrackers)
      ..where((t) => t.id.equals(id))
      ..limit(1);
    return query.watch().map(
      (rows) => rows.isEmpty ? null : _toEntity(rows.first),
    );
  }

  Future<void> cacheServerRow(Map<String, dynamic> row) {
    return _db
        .into(_db.localTrackers)
        .insertOnConflictUpdate(RowMappers.tracker(row));
  }

  Future<void> removeFromCache(String id) {
    return (_db.delete(_db.localTrackers)..where((t) => t.id.equals(id))).go();
  }

  TrackerEntity _toEntity(LocalTrackerRow r) {
    return TrackerEntity(
      id: r.id,
      name: r.name,
      type: r.type,
      startDate: r.startDate,
      endDate: r.endDate,
      budget: r.budget == null ? null : Money(r.budget!),
      description: r.description,
      status: r.status,
    );
  }
}

final trackersRepositoryProvider = Provider<TrackersRepository>(
  (ref) => TrackersRepository(ref.watch(appDatabaseProvider)),
  name: 'trackersRepository',
);
