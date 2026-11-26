import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/goals/application/goal_editor_controller.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/goals/data/goal_write_gateway.dart';
import 'package:finroot_mobile/features/goals/domain/goal_draft.dart';
import 'package:finroot_mobile/features/goals/domain/goal_history.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements GoalWriteGateway {
  final List<String> calls = [];
  double contributeAmount = 0;

  Map<String, dynamic> _row(String id, GoalDraft d) => {
    'id': id,
    'tenant_id': 't1',
    'title': d.title.trim(),
    'category': d.category,
    'target_amount': d.target.amount.toDouble(),
    'current_amount': 0,
    'currency': 'INR',
    'target_date': null,
    'status': 'active',
    'updated_at': '2026-09-09T00:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> create(String t, String? u, GoalDraft d) async {
    calls.add('create');
    return _row('goal-new', d);
  }

  @override
  Future<Map<String, dynamic>> update(String t, String id, GoalDraft d) async {
    calls.add('update:$id');
    return _row(id, d);
  }

  @override
  Future<void> delete(String t, String id) async => calls.add('delete:$id');

  String? lastNote;
  int historyReads = 0;
  GoalHistory historyResult = const GoalHistory([]);

  @override
  Future<GoalHistory> history(String t, String goalId, String currency) async {
    historyReads++;
    return historyResult;
  }

  @override
  Future<GoalContribution> contribute(
    String goalId,
    double amount, {
    String? note,
  }) async {
    calls.add('contribute:$goalId:$amount');
    lastNote = note;
    historyReads = 0;
    contributeAmount = amount;
    final current = amount.clamp(0, 10000).toDouble();
    return GoalContribution.fromRpc({
      'applied': amount,
      'current_amount': current,
      'target_amount': 10000,
      'status': current >= 10000 ? 'completed' : 'active',
      'capped': false,
    });
  }
}

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;

  setUp(() {
    db = AppDatabase.forTesting();
    gateway = _FakeGateway();
  });
  tearDown(() => db.close());

  ProviderContainer container({
    WorkspaceRole role = WorkspaceRole.owner,
    bool online = true,
    MenuStatus menu = MenuStatus.available,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentTenantIdProvider.overrideWithValue('t1'),
        currentUserIdProvider.overrideWithValue('u1'),
        currentRoleProvider.overrideWithValue(role),
        isOnlineProvider.overrideWithValue(online),
        goalWriteGatewayProvider.overrideWithValue(gateway),
        menuStatusProvider(FeatureMenu.goals).overrideWithValue(menu),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  final draft = GoalDraft(
    title: 'Emergency fund',
    target: Money.parse('10000'),
  );

  test('create folds the goal into the cache', () async {
    final id = await container()
        .read(goalEditorControllerProvider)
        .create(draft);
    expect(id, 'goal-new');
    final rows = await db.select(db.localGoals).get();
    expect(rows.single.title, 'Emergency fund');
    expect(rows.single.targetAmount, Decimal.parse('10000'));
  });

  test(
    'contribute goes through the RPC and applies the outcome locally',
    () async {
      await db
          .into(db.localGoals)
          .insert(
            LocalGoalsCompanion.insert(
              id: 'g1',
              tenantId: 't1',
              title: 'Trip',
              targetAmount: Decimal.parse('10000'),
              currentAmount: Decimal.parse('2000'),
            ),
          );

      final result = await container()
          .read(goalEditorControllerProvider)
          .contribute('g1', 3000);

      expect(gateway.calls, contains('contribute:g1:3000.0'));
      expect(result.applied.amount, Decimal.parse('3000'));
      final row = await (db.select(
        db.localGoals,
      )..where((g) => g.id.equals('g1'))).getSingle();
      expect(row.currentAmount, Decimal.parse('3000')); // clamped fake
    },
  );

  test('a locked goals menu refuses every write', () async {
    await expectLater(
      container(menu: MenuStatus.locked)
          .read(goalEditorControllerProvider)
          .create(draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gateway.calls, isEmpty);
  });

  test('offline is refused', () async {
    await expectLater(
      container(online: false).read(goalEditorControllerProvider).create(draft),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('a viewer is refused', () async {
    await expectLater(
      container(role: WorkspaceRole.viewer)
          .read(goalEditorControllerProvider)
          .create(draft),
      throwsA(isA<PermissionFailure>()),
    );
  });

  group('contribution history', () {
    const key = (goalId: 'g1', currency: 'INR');

    Future<void> seed() => db
        .into(db.localGoals)
        .insert(
          LocalGoalsCompanion.insert(
            id: 'g1',
            tenantId: 't1',
            title: 'Trip',
            targetAmount: Decimal.parse('10000'),
            currentAmount: Decimal.parse('0'),
          ),
        );

    test('the note is passed to the RPC', () async {
      await seed();
      await container()
          .read(goalEditorControllerProvider)
          .contribute('g1', 500, note: 'Diwali bonus');
      expect(gateway.lastNote, 'Diwali bonus');
    });

    test(
      'reads the shared history and refreshes after a contribution',
      () async {
        await seed();
        gateway.historyResult = GoalHistory([
          GoalContributionEntry.fromRow({
            'id': 'c1',
            'goal_id': 'g1',
            'amount': '500.00',
            'note': 'Diwali bonus',
            'contributed_at': '2026-11-20T10:00:00Z',
          }),
        ]);
        final c = container();
        final sub = c.listen(goalHistoryProvider(key), (_, _) {});
        addTearDown(sub.close);

        final h = await c.read(goalHistoryProvider(key).future);
        expect(h.missing, isFalse);
        expect(h.entries.single.note, 'Diwali bonus');
        expect(h.entries.single.amount.amount, Decimal.parse('500'));

        await c.read(goalEditorControllerProvider).contribute('g1', 100);
        await c.read(goalHistoryProvider(key).future);
        expect(gateway.historyReads, 1); // re-read after the contribution
      },
    );

    test('a missing table surfaces as missing, not an error', () async {
      gateway.historyResult = const GoalHistory.missing();
      final c = container();
      final sub = c.listen(goalHistoryProvider(key), (_, _) {});
      addTearDown(sub.close);
      final h = await c.read(goalHistoryProvider(key).future);
      expect(h.missing, isTrue);
      expect(h.entries, isEmpty);
    });

    test('offline history is a NetworkFailure', () async {
      final c = container(online: false);
      final sub = c.listen(goalHistoryProvider(key), (_, _) {});
      addTearDown(sub.close);
      await expectLater(
        c.read(goalHistoryProvider(key).future),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });
}
