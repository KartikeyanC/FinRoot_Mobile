import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/goals/data/goals_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late GoalsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = GoalsRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert({
    required String id,
    String title = 'Trip',
    String target = '10000',
    String current = '0',
    String tenant = 't1',
  }) {
    return db.into(db.localGoals).insert(
      LocalGoalsCompanion.insert(
        id: id,
        tenantId: tenant,
        title: title,
        targetAmount: Decimal.parse(target),
        currentAmount: Decimal.parse(current),
      ),
    );
  }

  test('watchAll scopes to the tenant, A→Z by title', () async {
    await insert(id: 'b', title: 'Bike');
    await insert(id: 'a', title: 'Apartment');
    await insert(id: 'x', title: 'Xylophone', tenant: 't2');

    final goals = await repo.watchAll('t1').first;
    expect(goals.map((g) => g.title), ['Apartment', 'Bike']);
  });

  test('maps target / current as Money and computes progress', () async {
    await insert(id: 'g', current: '2500');
    final g = (await repo.watchAll('t1').first).single;
    expect(g.target.amount, Decimal.parse('10000'));
    expect(g.current.amount, Decimal.parse('2500'));
    expect(g.progressPercent, 25);
  });

  test('applyContribution updates current + status', () async {
    await insert(id: 'g', current: '2000');
    await repo.applyContribution('g', Money.parse('10000'), 'completed');

    final g = await repo.watchById('g').first;
    expect(g!.current.amount, Decimal.parse('10000'));
    expect(g.status, 'completed');
    expect(g.isComplete, isTrue);
  });

  test('cacheServerRow folds a goals row in', () async {
    await repo.cacheServerRow({
      'id': 'srv',
      'tenant_id': 't1',
      'title': 'House deposit',
      'category': 'Home',
      'target_amount': 2000000,
      'current_amount': 150000,
      'currency': 'INR',
      'target_date': null,
      'status': 'active',
      'updated_at': '2026-09-09T00:00:00Z',
    });
    final g = await repo.watchById('srv').first;
    expect(g!.title, 'House deposit');
    expect(g.category, 'Home');
    expect(g.current.amount, Decimal.parse('150000'));
  });
}
