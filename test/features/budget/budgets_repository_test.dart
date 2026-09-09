import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/budget/data/budgets_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BudgetsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = BudgetsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert({
    required String id,
    String bucket = 'Needs',
    String allocated = '30000',
    String tenant = 't1',
    required DateTime periodStart,
  }) {
    return db.into(db.localBudgets).insert(
      LocalBudgetsCompanion.insert(
        id: id,
        tenantId: tenant,
        bucket: bucket,
        allocated: Decimal.parse(allocated),
        periodStart: periodStart,
        period: const Value('monthly'),
      ),
    );
  }

  test('watchForPeriod matches by calendar date and scopes to tenant', () async {
    await insert(id: 'march', periodStart: DateTime.utc(2026, 3));
    await insert(
      id: 'march-t2',
      tenant: 't2',
      periodStart: DateTime.utc(2026, 3),
    );
    await insert(
      id: 'april',
      bucket: 'Play',
      periodStart: DateTime.utc(2026, 4),
    );

    final march = await repo
        .watchForPeriod('t1', DateTime.utc(2026, 3))
        .first;
    expect(march.map((b) => b.id), ['march']);
  });

  test('cacheServerRow folds a budget_set_allocation row in', () async {
    await repo.cacheServerRow({
      'id': 'srv',
      'tenant_id': 't1',
      'bucket': 'Education',
      'allocated': 12000,
      'period': 'monthly',
      'period_start': '2026-03-01',
      'updated_at': '2026-09-09T00:00:00Z',
    });
    final rows = await repo
        .watchForPeriod('t1', DateTime.utc(2026, 3))
        .first;
    expect(rows.single.bucket, 'Education');
    expect(rows.single.allocated.amount, Decimal.parse('12000'));
  });
}
