import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/trackers/application/tracker_editor_controller.dart';
import 'package:finroot_mobile/features/trackers/data/tracker_gateways.dart';
import 'package:finroot_mobile/features/trackers/domain/tracker_draft.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements TrackerWriteGateway {
  final List<String> calls = [];
  Map<String, dynamic> _row(String id, {String status = 'active'}) => {
    'id': id,
    'tenant_id': 't1',
    'name': 'Dubai Trip',
    'type': 'Travel',
    'start_date': '2026-03-02',
    'end_date': null,
    'budget': 50000,
    'currency': 'INR',
    'description': null,
    'status': status,
    'deleted_at': null,
    'updated_at': '2026-09-09T00:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> create(String t, String? u, TrackerDraft d) async {
    calls.add('create');
    return _row('trk-new');
  }

  @override
  Future<Map<String, dynamic>> update(String t, String id, TrackerDraft d) async {
    calls.add('update:$id');
    return _row(id);
  }

  @override
  Future<Map<String, dynamic>> setStatus(
    String t,
    String id,
    TrackerStatus s,
  ) async {
    calls.add('status:$id:${s.name}');
    return _row(id, status: s.name);
  }

  @override
  Future<void> softDelete(String t, String id) async => calls.add('delete:$id');

  @override
  Future<void> assign(String t, String trackerId, List<String> ids) async =>
      calls.add('assign:$trackerId:${ids.join(",")}');

  @override
  Future<void> unassign(String t, String id) async => calls.add('unassign:$id');
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
        trackerWriteGatewayProvider.overrideWithValue(gateway),
        menuStatusProvider(FeatureMenu.trackers).overrideWithValue(menu),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  TrackerEditorController ctl(ProviderContainer c) =>
      c.read(trackerEditorControllerProvider);

  final draft = TrackerDraft(
    name: 'Dubai Trip',
    type: 'Travel',
    startDate: DateTime.utc(2026, 3, 2),
  );

  test('create writes to the server and folds the tracker into the cache', () async {
    final id = await ctl(container()).create(draft);
    expect(id, 'trk-new');
    final rows = await db.select(db.localTrackers).get();
    expect(rows.single.name, 'Dubai Trip');
    expect(rows.single.status, 'active');
  });

  test('setStatus completed updates the cached row', () async {
    await db.into(db.localTrackers).insert(
      LocalTrackersCompanion.insert(
        id: 'trk-1',
        tenantId: 't1',
        name: 'Dubai Trip',
        type: 'Travel',
        startDate: DateTime.utc(2026, 3, 2),
      ),
    );
    await ctl(container()).setStatus('trk-1', TrackerStatus.completed);
    final row = await (db.select(
      db.localTrackers,
    )..where((t) => t.id.equals('trk-1'))).getSingle();
    expect(row.status, 'completed');
  });

  test('delete soft-deletes server-side and removes it from the cache', () async {
    await db.into(db.localTrackers).insert(
      LocalTrackersCompanion.insert(
        id: 'trk-9',
        tenantId: 't1',
        name: 'X',
        type: 'Custom',
        startDate: DateTime.utc(2026, 3, 2),
      ),
    );
    await ctl(container()).delete('trk-9');
    expect(gateway.calls, contains('delete:trk-9'));
    expect(await db.select(db.localTrackers).get(), isEmpty);
  });

  test('assign tags the cached transactions; unassign clears them', () async {
    await db.into(db.localTransactions).insert(
      LocalTransactionsCompanion.insert(
        id: 'txn-1',
        tenantId: 't1',
        type: 'expense',
        amount: Decimal.parse('100.00'),
        category: 'Other',
        occurredAt: DateTime.utc(2026, 3, 5),
      ),
    );

    await ctl(container()).assign('trk-1', ['txn-1']);
    var row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('txn-1'))).getSingle();
    expect(row.trackerId, 'trk-1');
    expect(gateway.calls, contains('assign:trk-1:txn-1'));

    await ctl(container()).unassign('txn-1');
    row = await (db.select(
      db.localTransactions,
    )..where((t) => t.id.equals('txn-1'))).getSingle();
    expect(row.trackerId, isNull);
  });

  test('a locked trackers menu refuses the write', () async {
    await expectLater(
      ctl(container(menu: MenuStatus.locked)).create(draft),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gateway.calls, isEmpty);
  });

  test('a viewer is refused', () async {
    await expectLater(
      ctl(container(role: WorkspaceRole.viewer)).create(draft),
      throwsA(isA<PermissionFailure>()),
    );
  });

  test('offline is refused (no offline queue for trackers in V1)', () async {
    await expectLater(
      ctl(container(online: false)).create(draft),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
