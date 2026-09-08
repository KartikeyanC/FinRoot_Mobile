/// A workspace the signed-in user belongs to, plus their role in it.
///
/// Mirrors the web `TenantContext` shape (M1 audit §8). RLS returns finance
/// rows for *every* workspace the user is a member of, so the app must always
/// scope reads and writes to one chosen `tenantId` — see
/// `currentTenantIdProvider`.
library;

enum WorkspaceRole {
  owner,
  admin,
  viewer;

  static WorkspaceRole fromWire(String value) => switch (value) {
    'owner' => WorkspaceRole.owner,
    'admin' => WorkspaceRole.admin,
    _ => WorkspaceRole.viewer,
  };

  /// admin and owner can create/edit/delete finance data; viewer is read-only
  /// (web BR: "Create/edit/delete data" — viewer ✖).
  bool get canWrite =>
      this == WorkspaceRole.owner || this == WorkspaceRole.admin;

  String get label => switch (this) {
    WorkspaceRole.owner => 'Owner',
    WorkspaceRole.admin => 'Admin',
    WorkspaceRole.viewer => 'Viewer',
  };
}

class Membership {
  const Membership({
    required this.tenantId,
    required this.name,
    required this.tenantStatus,
    required this.role,
  });

  final String tenantId;
  final String name;

  /// `active` | `suspended` | `deleted` (web `tenants.status`).
  final String tenantStatus;
  final WorkspaceRole role;

  bool get isDeleted => tenantStatus == 'deleted';
  bool get isSuspended => tenantStatus == 'suspended';
  bool get isUsable => !isDeleted;

  /// Row shape from
  /// `tenant_members.select('tenant_id, role, status, tenants(name, status)')`.
  factory Membership.fromRow(Map<String, dynamic> row) {
    final tenant = row['tenants'];
    final tenantMap = tenant is Map<String, dynamic>
        ? tenant
        : const <String, dynamic>{};
    return Membership(
      tenantId: row['tenant_id'] as String,
      name: (tenantMap['name'] as String?)?.trim().isNotEmpty == true
          ? tenantMap['name'] as String
          : 'Workspace',
      tenantStatus: (tenantMap['status'] as String?) ?? 'active',
      role: WorkspaceRole.fromWire((row['role'] as String?) ?? 'viewer'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Membership &&
      other.tenantId == tenantId &&
      other.role == role &&
      other.tenantStatus == tenantStatus &&
      other.name == name;

  @override
  int get hashCode => Object.hash(tenantId, role, tenantStatus, name);
}

/// Given all memberships and the last stored choice, pick the workspace to use.
/// Pure so the reconciliation rule is tested directly (mirrors the web
/// `TenantContext` "stillValid / fallback to first non-deleted" logic).
String? resolveCurrentTenantId(List<Membership> memberships, String? stored) {
  if (memberships.isEmpty) return null;
  final storedIsUsable =
      stored != null &&
      memberships.any((m) => m.tenantId == stored && m.isUsable);
  if (storedIsUsable) return stored;
  final firstUsable = memberships.where((m) => m.isUsable);
  return firstUsable.isNotEmpty
      ? firstUsable.first.tenantId
      : memberships.first.tenantId;
}
