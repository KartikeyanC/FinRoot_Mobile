import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../summary/application/summary_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/account_write_gateway.dart';
import '../data/accounts_repository.dart';
import '../domain/account_draft.dart';

/// Create / edit / delete an account. Online-only (V1 — no offline queue for
/// accounts): the write hits PostgREST, then the returned row is folded into
/// the cache so the list updates immediately. A `Failure` is thrown for the
/// sheet to show.
class AccountEditorController {
  AccountEditorController(this._ref);

  final Ref _ref;

  Future<void> create(AccountDraft draft) =>
      _write((tenantId, userId, repo) async {
        final row = await _ref
            .read(accountWriteGatewayProvider)
            .create(tenantId, userId, draft);
        await repo.cacheServerRow(row);
      });

  Future<void> update(String id, AccountDraft draft) =>
      _write((tenantId, userId, repo) async {
        final row = await _ref
            .read(accountWriteGatewayProvider)
            .update(tenantId, id, draft);
        await repo.cacheServerRow(row);
      });

  Future<void> delete(String id) => _write((tenantId, userId, repo) async {
    await _ref.read(accountWriteGatewayProvider).delete(tenantId, id);
    await repo.removeFromCache(id);
  });

  /// The stored opening date of account [id], for pre-filling the edit form
  /// (the local cache does not keep it). Null when unset, offline, or with no
  /// workspace — the form then just shows an empty picker.
  Future<DateTime?> openingDate(String id) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null || !_ref.read(isOnlineProvider)) return null;
    return _ref
        .read(accountWriteGatewayProvider)
        .fetchOpeningDate(tenantId, id);
  }

  Future<void> _write(
    Future<void> Function(
      String tenantId,
      String? userId,
      AccountsRepository repo,
    )
    action,
  ) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();

    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (!_ref.read(isOnlineProvider)) {
      throw const NetworkFailure();
    }

    await action(
      tenantId,
      _ref.read(currentUserIdProvider),
      _ref.read(accountsRepositoryProvider),
    );

    // Opening balances / account set changed → the Home total and the
    // per-account balances need the fresh roll-up.
    _ref.invalidate(workspaceSummaryProvider);
  }
}

final accountEditorControllerProvider = Provider<AccountEditorController>(
  (ref) => AccountEditorController(ref),
  name: 'accountEditorController',
);
