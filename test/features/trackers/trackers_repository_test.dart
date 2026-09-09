import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/trackers/data/trackers_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TrackersRepository repo;

  setUp(() {
    db = AppDatabase.forTesting();
    repo = TrackersRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insertTracker({
    required String id,
    String tenant = 't1',
    String name = 'Home Construction',
    String type = 'Home Construction',
    String status = 'active',
    String? budget,
    required DateTime startDate,
  }) {
    return db
        .into(db.localTrackers)
        .insert(
          LocalTrackersCompanion.insert(
            id: id,
            tenantId: tenant,
            name: name,
            type: type,
            startDate: startDate,
            status: Value(status),
            budget: Value(budget == null ? null : Decimal.parse(budget)),
          ),
        );
  }

  test('watchActive returns only active trackers for the tenant', () async {
    await insertTracker(id: 'a', startDate: DateTime.utc(2026, 3, 2));
    await insertTracker(
      id: 'done',
      status: 'completed',
      startDate: DateTime.utc(2026, 4, 2),
    );
    await insertTracker(
      id: 'other',
      tenant: 't2',
      startDate: DateTime.utc(2026, 5, 2),
    );

    final active = await repo.watchActive('t1').first;

    expect(active.map((t) => t.id), ['a']);
  });

  test('watchActive orders by start date, newest first', () async {
    await insertTracker(id: 'old', startDate: DateTime.utc(2026, 1, 2));
    await insertTracker(id: 'new', startDate: DateTime.utc(2026, 6, 2));

    final active = await repo.watchActive('t1').first;

    expect(active.map((t) => t.id), ['new', 'old']);
  });

  test('maps the server-set budget as INR Money, or null', () async {
    await insertTracker(
      id: 'budgeted',
      budget: '250000.00',
      startDate: DateTime.utc(2026, 3, 2),
    );
    await insertTracker(id: 'open', startDate: DateTime.utc(2026, 2, 2));

    final active = await repo.watchActive('t1').first;
    final budgeted = active.firstWhere((t) => t.id == 'budgeted');
    final open = active.firstWhere((t) => t.id == 'open');

    expect(budgeted.budget!.amount, Decimal.parse('250000.00'));
    expect(budgeted.budget!.currency, 'INR');
    expect(open.budget, isNull);
  });
}
