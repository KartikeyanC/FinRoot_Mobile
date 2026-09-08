import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../domain/membership.dart';

/// Reads the signed-in user's workspace memberships.
///
/// Scoped to `user_id = auth.uid()` explicitly: the `tenant_members` RLS policy
/// also lets a platform admin read every row, so an unfiltered query could
/// return other tenants' membership rows (web `TenantContext` comment).
class MembershipRepository {
  MembershipRepository(this._client);

  final SupabaseClient _client;
  final _log = AppLog.of('workspace');

  Future<List<Membership>> fetchForCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      final rows = await _client
          .from('tenant_members')
          .select('tenant_id, role, status, tenants(name, status)')
          .eq('user_id', userId)
          .eq('status', 'active');
      final list = rows
          .map((r) => Membership.fromRow(r))
          .toList(growable: false);
      _log.info('loaded ${list.length} membership(s)');
      return list;
    } catch (error, stack) {
      _log.warning('membership fetch failed');
      throw mapError(error, stack);
    }
  }

  /// Effective feature menus for a workspace: `get_effective_menus(tenant_id)`
  /// = plan ceiling − tenant deny ∩ member allow (web `has_menu` contract,
  /// M1 audit §8). Drives which "More" entries are available.
  Future<Set<String>> fetchEffectiveMenus(String tenantId) async {
    try {
      final result = await _client.rpc<dynamic>(
        'get_effective_menus',
        params: {'p_tenant_id': tenantId},
      );
      if (result is List) {
        return result.whereType<String>().toSet();
      }
      return const {};
    } catch (error, stack) {
      _log.warning('get_effective_menus failed');
      throw mapError(error, stack);
    }
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(ref.watch(supabaseClientProvider)),
  name: 'membershipRepository',
);
