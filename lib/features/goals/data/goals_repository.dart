import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../sync/data/row_mappers.dart';
import '../domain/goal.dart';

/// Reads goals from the M4 cache; folds a server row back in after an online
/// write / contribution.
class GoalsRepository {
  GoalsRepository(this._db);

  final AppDatabase _db;

  Stream<List<GoalEntity>> watchAll(String tenantId) {
    final query = _db.select(_db.localGoals)
      ..where((g) => g.tenantId.equals(tenantId))
      ..orderBy([(g) => OrderingTerm.asc(g.title)]);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  Stream<GoalEntity?> watchById(String id) {
    final query = _db.select(_db.localGoals)
      ..where((g) => g.id.equals(id))
      ..limit(1);
    return query.watch().map(
      (rows) => rows.isEmpty ? null : _toEntity(rows.first),
    );
  }

  Future<void> cacheServerRow(Map<String, dynamic> row) {
    return _db
        .into(_db.localGoals)
        .insertOnConflictUpdate(RowMappers.goal(row));
  }

  Future<void> removeFromCache(String id) {
    return (_db.delete(_db.localGoals)..where((g) => g.id.equals(id))).go();
  }

  /// Optimistically apply a `goal_contribute` outcome (which returns figures,
  /// not the whole row) to the cached goal.
  Future<void> applyContribution(
    String id,
    Money current,
    String status,
  ) {
    return (_db.update(_db.localGoals)..where((g) => g.id.equals(id))).write(
      LocalGoalsCompanion(
        currentAmount: Value(current.amount),
        status: Value(status),
      ),
    );
  }

  GoalEntity _toEntity(LocalGoalRow r) => GoalEntity(
    id: r.id,
    title: r.title,
    target: Money(r.targetAmount, r.currency),
    current: Money(r.currentAmount, r.currency),
    category: r.category,
    currency: r.currency,
    targetDate: r.targetDate,
    status: r.status,
  );
}

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(appDatabaseProvider)),
  name: 'goalsRepository',
);
