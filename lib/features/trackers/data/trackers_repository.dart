import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../domain/tracker.dart';

/// Reads trackers out of the local cache (M4). Like [TransactionsRepository]
/// this is an offline read layer over a cache the sync engine keeps fresh;
/// tracker spend and progress stay server-derived (ADR-0006) and land with the
/// tracker feature in M9. M6 only needs the active list for the Home feed.
class TrackersRepository {
  TrackersRepository(this._db);

  final AppDatabase _db;

  /// Active trackers for [tenantId], most recently started first.
  Stream<List<TrackerEntity>> watchActive(String tenantId) {
    final query = _db.select(_db.localTrackers)
      ..where((t) => t.tenantId.equals(tenantId) & t.status.equals('active'))
      ..orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
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
