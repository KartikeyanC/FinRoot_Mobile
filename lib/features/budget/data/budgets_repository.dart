import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/database_providers.dart';
import '../../sync/data/row_mappers.dart';
import '../domain/budget_spend.dart';

/// Reads budget rows from the M4 cache, and folds a server row back in after an
/// online allocation write. Spend stays server-derived (ADR-0006 —
/// `budgets.spent` is never read).
class BudgetsRepository {
  BudgetsRepository(this._db);

  final AppDatabase _db;

  /// Budget rows for [tenantId] whose `period_start` matches [periodStart]
  /// (compared on the calendar date), bucket A→Z.
  Stream<List<BudgetEntity>> watchForPeriod(
    String tenantId,
    DateTime periodStart,
  ) {
    final startOfDay = DateTime.utc(
      periodStart.year,
      periodStart.month,
      periodStart.day,
    );
    final nextDay = startOfDay.add(const Duration(days: 1));
    final query = _db.select(_db.localBudgets)
      ..where(
        (b) =>
            b.tenantId.equals(tenantId) &
            b.periodStart.isBiggerOrEqualValue(startOfDay) &
            b.periodStart.isSmallerThanValue(nextDay),
      )
      ..orderBy([(b) => OrderingTerm.asc(b.bucket)]);
    return query.watch().map(
      (rows) => rows.map(_toEntity).toList(growable: false),
    );
  }

  Future<void> cacheServerRow(Map<String, dynamic> row) {
    return _db
        .into(_db.localBudgets)
        .insertOnConflictUpdate(RowMappers.budget(row));
  }

  Future<void> removeFromCache(String id) {
    return (_db.delete(_db.localBudgets)..where((b) => b.id.equals(id))).go();
  }

  BudgetEntity _toEntity(LocalBudgetRow r) => BudgetEntity(
    id: r.id,
    bucket: r.bucket,
    allocated: Money(r.allocated),
    period: r.period,
    periodStart: r.periodStart,
  );
}

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(appDatabaseProvider)),
  name: 'budgetsRepository',
);
