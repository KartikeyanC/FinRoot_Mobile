import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/data/local/database_providers.dart';
import 'package:finroot_mobile/features/accounts/application/account_editor_controller.dart';
import 'package:finroot_mobile/features/accounts/data/account_write_gateway.dart';
import 'package:finroot_mobile/features/accounts/domain/account_draft.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGateway implements AccountWriteGateway {
  final List<String> deleted = [];
  Map<String, dynamic>? lastCreate;
  Map<String, dynamic>? lastUpdate;

  Map<String, dynamic> _row(String id, AccountDraft d) => {
    'id': id,
    'tenant_id': 't1',
    'name': d.name.trim(),
    'type': d.type,
    'opening_balance': d.openingBalance?.amount.toDouble(),
    'color': null,
    'icon': null,
    'updated_at': '2026-09-09T00:00:00Z',
  };

  @override
  Future<Map<String, dynamic>> create(
    String tenantId,
    String? userId,
    AccountDraft draft,
  ) async {
    lastCreate = _row('acc-new', draft);
    return lastCreate!;
  }

  @override
  Future<Map<String, dynamic>> update(
    String tenantId,
    String id,
    AccountDraft draft,
  ) async {
    lastUpdate = _row(id, draft);
    return lastUpdate!;
  }

  @override
  Future<void> delete(String tenantId, String id) async => deleted.add(id);
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
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentTenantIdProvider.overrideWithValue('t1'),
        currentUserIdProvider.overrideWithValue('u1'),
        currentRoleProvider.overrideWithValue(role),
        isOnlineProvider.overrideWithValue(online),
        accountWriteGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('create writes to the server and folds the row into the cache', () async {
    final c = container();
    await c.read(accountEditorControllerProvider).create(
      const AccountDraft(name: '  SBI  ', type: 'bank'),
    );

    expect(gateway.lastCreate, isNotNull);
    final rows = await db.select(db.localAccounts).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'SBI');
    expect(rows.single.type, 'bank');
  });

  test('update PATCHes and refreshes the cached row', () async {
    // seed a cached account
    await db
        .into(db.localAccounts)
        .insert(
          LocalAccountsCompanion.insert(
            id: 'acc-1',
            tenantId: 't1',
            name: 'Old',
            type: 'cash',
          ),
        );
    final c = container();

    await c.read(accountEditorControllerProvider).update(
      'acc-1',
      AccountDraft(
        name: 'New name',
        type: 'wallet',
        openingBalance: Money.parse('500.00'),
      ),
    );

    final row = await (db.select(
      db.localAccounts,
    )..where((a) => a.id.equals('acc-1'))).getSingle();
    expect(row.name, 'New name');
    expect(row.type, 'wallet');
  });

  test('delete removes it server-side and from the cache', () async {
    await db
        .into(db.localAccounts)
        .insert(
          LocalAccountsCompanion.insert(
            id: 'acc-9',
            tenantId: 't1',
            name: 'Gone',
            type: 'other',
          ),
        );
    final c = container();

    await c.read(accountEditorControllerProvider).delete('acc-9');

    expect(gateway.deleted, ['acc-9']);
    final rows = await db.select(db.localAccounts).get();
    expect(rows, isEmpty);
  });

  test('a viewer is refused', () async {
    final c = container(role: WorkspaceRole.viewer);
    await expectLater(
      c.read(accountEditorControllerProvider).create(
        const AccountDraft(name: 'X', type: 'bank'),
      ),
      throwsA(isA<PermissionFailure>()),
    );
    expect(gateway.lastCreate, isNull);
  });

  test('offline is refused (no offline queue for accounts in V1)', () async {
    final c = container(online: false);
    await expectLater(
      c.read(accountEditorControllerProvider).create(
        const AccountDraft(name: 'X', type: 'bank'),
      ),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
