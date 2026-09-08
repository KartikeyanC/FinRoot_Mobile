import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_prefs.dart';
import '../../../core/providers/providers.dart';
import '../data/membership_repository.dart';
import '../domain/membership.dart';

/// The signed-in user's workspaces. Reloads when auth state changes; empty when
/// signed out. A real account always has at least one (the signup trigger
/// creates a personal workspace) — an empty result after a successful load
/// means "no workspace", which the router routes to a dedicated screen.
final membershipsProvider =
    AsyncNotifierProvider<MembershipsNotifier, List<Membership>>(
      MembershipsNotifier.new,
      name: 'memberships',
    );

class MembershipsNotifier extends AsyncNotifier<List<Membership>> {
  @override
  Future<List<Membership>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];
    return ref.read(membershipRepositoryProvider).fetchForCurrentUser();
  }

  /// Retry after a failed load (the "no workspace" and error states offer this).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(membershipRepositoryProvider).fetchForCurrentUser(),
    );
  }
}

/// The raw stored workspace choice — what the user last selected, before it is
/// checked against reality. [select] persists it.
final _storedTenantIdProvider =
    NotifierProvider<StoredTenantIdController, String?>(
      StoredTenantIdController.new,
      name: 'storedTenantId',
    );

class StoredTenantIdController extends Notifier<String?> {
  @override
  String? build() => ref.watch(devicePrefsProvider).tenantId;

  Future<void> select(String tenantId) async {
    await ref.read(devicePrefsProvider).setTenantId(tenantId);
    state = tenantId;
  }

  Future<void> clear() async {
    await ref.read(devicePrefsProvider).setTenantId(null);
    state = null;
  }
}

/// The workspace to actually use: the stored choice if it is still a live
/// membership, otherwise the first usable one, otherwise null. Every finance
/// read/write scopes to this (RLS returns rows for all workspaces the user is
/// in — M1 audit §8, R-8).
final currentTenantIdProvider = Provider<String?>((ref) {
  final memberships =
      ref.watch(membershipsProvider).value ?? const <Membership>[];
  final stored = ref.watch(_storedTenantIdProvider);
  return resolveCurrentTenantId(memberships, stored);
}, name: 'currentTenantId');

final currentMembershipProvider = Provider<Membership?>((ref) {
  final id = ref.watch(currentTenantIdProvider);
  if (id == null) return null;
  final memberships =
      ref.watch(membershipsProvider).value ?? const <Membership>[];
  for (final m in memberships) {
    if (m.tenantId == id) return m;
  }
  return null;
}, name: 'currentMembership');

/// The user's role in the active workspace. `null` until memberships load.
final currentRoleProvider = Provider<WorkspaceRole?>(
  (ref) => ref.watch(currentMembershipProvider)?.role,
  name: 'currentRole',
);

/// Switch the active workspace.
final workspaceControllerProvider = Provider<WorkspaceController>(
  (ref) => WorkspaceController(ref),
  name: 'workspaceController',
);

class WorkspaceController {
  WorkspaceController(this._ref);
  final Ref _ref;

  Future<void> select(String tenantId) =>
      _ref.read(_storedTenantIdProvider.notifier).select(tenantId);

  Future<void> refreshMemberships() =>
      _ref.read(membershipsProvider.notifier).refresh();
}
