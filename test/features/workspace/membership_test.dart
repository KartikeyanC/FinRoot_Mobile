import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter_test/flutter_test.dart';

Membership _m(
  String id, {
  String status = 'active',
  WorkspaceRole role = WorkspaceRole.owner,
}) =>
    Membership(tenantId: id, name: 'WS $id', tenantStatus: status, role: role);

void main() {
  group('WorkspaceRole', () {
    test('fromWire maps known roles and defaults to viewer', () {
      expect(WorkspaceRole.fromWire('owner'), WorkspaceRole.owner);
      expect(WorkspaceRole.fromWire('admin'), WorkspaceRole.admin);
      expect(WorkspaceRole.fromWire('viewer'), WorkspaceRole.viewer);
      expect(WorkspaceRole.fromWire('nonsense'), WorkspaceRole.viewer);
    });

    test('canWrite: owner/admin yes, viewer no (web BR)', () {
      expect(WorkspaceRole.owner.canWrite, isTrue);
      expect(WorkspaceRole.admin.canWrite, isTrue);
      expect(WorkspaceRole.viewer.canWrite, isFalse);
    });
  });

  group('Membership.fromRow', () {
    test('reads the joined tenants(name, status)', () {
      final m = Membership.fromRow({
        'tenant_id': 't1',
        'role': 'admin',
        'status': 'active',
        'tenants': {'name': 'Home', 'status': 'active'},
      });
      expect(m.tenantId, 't1');
      expect(m.name, 'Home');
      expect(m.role, WorkspaceRole.admin);
      expect(m.isUsable, isTrue);
    });

    test('tolerates a missing tenant join and a blank name', () {
      final m = Membership.fromRow({
        'tenant_id': 't2',
        'role': 'viewer',
        'status': 'active',
      });
      expect(m.name, 'Workspace');
      expect(m.tenantStatus, 'active');
    });

    test('flags a deleted / suspended tenant', () {
      final deleted = Membership.fromRow({
        'tenant_id': 't3',
        'role': 'owner',
        'status': 'active',
        'tenants': {'name': 'Old', 'status': 'deleted'},
      });
      expect(deleted.isDeleted, isTrue);
      expect(deleted.isUsable, isFalse);
    });
  });

  group(
    'resolveCurrentTenantId (mirrors web TenantContext reconciliation)',
    () {
      test('no memberships → null', () {
        expect(resolveCurrentTenantId(const [], 'anything'), isNull);
      });

      test('keeps a stored id that is still a live membership', () {
        final list = [_m('a'), _m('b')];
        expect(resolveCurrentTenantId(list, 'b'), 'b');
      });

      test(
        'falls back to the first usable one when the stored id is stale',
        () {
          final list = [_m('a'), _m('b')];
          expect(resolveCurrentTenantId(list, 'gone'), 'a');
        },
      );

      test('never selects a deleted workspace, even if stored', () {
        final list = [_m('a', status: 'deleted'), _m('b')];
        expect(resolveCurrentTenantId(list, 'a'), 'b');
      });

      test('null stored → first usable', () {
        final list = [_m('a', status: 'deleted'), _m('b'), _m('c')];
        expect(resolveCurrentTenantId(list, null), 'b');
      });
    },
  );
}
