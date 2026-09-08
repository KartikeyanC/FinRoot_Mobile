import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/constants.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/data/membership_repository.dart';

/// The effective feature menus for the active workspace, from
/// `get_effective_menus(tenant_id)`. Empty set when there is no workspace.
///
/// RLS is the real gate — this only decides what the UI *offers*. A feature
/// screen still handles a `PermissionFailure` if the server disagrees.
final effectiveMenusProvider = FutureProvider<Set<String>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const <String>{};
  return ref.watch(membershipRepositoryProvider).fetchEffectiveMenus(tenantId);
}, name: 'effectiveMenus');

/// Availability of one feature menu, resolved for the UI.
enum MenuStatus {
  /// In the workspace's effective menus — show and allow.
  available,

  /// Not in the effective menus — show, but locked (no crash, no raw error).
  locked,

  /// Still loading, or the check failed — treat as available and let RLS
  /// decide. Never render a lock we are not sure about (web `menuUpsell`:
  /// "anything uncertain resolves to unknown and renders nothing").
  unknown,
}

final menuStatusProvider = Provider.family<MenuStatus, FeatureMenu>((
  ref,
  menu,
) {
  final async = ref.watch(effectiveMenusProvider);
  return async.when(
    data: (menus) =>
        menus.contains(menu.id) ? MenuStatus.available : MenuStatus.locked,
    loading: () => MenuStatus.unknown,
    error: (_, _) => MenuStatus.unknown,
  );
}, name: 'menuStatus');

/// Convenience: is this feature usable right now? `unknown` counts as usable.
final menuAvailableProvider = Provider.family<bool, FeatureMenu>(
  (ref, menu) => ref.watch(menuStatusProvider(menu)) != MenuStatus.locked,
  name: 'menuAvailable',
);
