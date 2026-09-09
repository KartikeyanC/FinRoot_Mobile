import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/tracker_gateways.dart';
import '../data/trackers_repository.dart';
import '../domain/tracker_draft.dart';
import 'trackers_providers.dart';

/// Create / edit / lifecycle / delete a tracker, and assign / unassign
/// transactions. Online-only (V1 — like accounts, M8): write to PostgREST,
/// then fold the result into the cache. A locked `trackers` menu (a real plan
/// paywall — ADR-0002) surfaces as a [PermissionFailure] before the request.
class TrackerEditorController {
  TrackerEditorController(this._ref);

  final Ref _ref;

  Future<String> create(TrackerDraft draft) async {
    final tenantId = _guard();
    final row = await _ref
        .read(trackerWriteGatewayProvider)
        .create(tenantId, _ref.read(currentUserIdProvider), draft);
    await _repo.cacheServerRow(row);
    _refresh();
    return row['id'] as String;
  }

  Future<void> update(String id, TrackerDraft draft) async {
    final tenantId = _guard();
    final row = await _ref
        .read(trackerWriteGatewayProvider)
        .update(tenantId, id, draft);
    await _repo.cacheServerRow(row);
    _refresh();
  }

  Future<void> setStatus(String id, TrackerStatus status) async {
    final tenantId = _guard();
    final row = await _ref
        .read(trackerWriteGatewayProvider)
        .setStatus(tenantId, id, status);
    await _repo.cacheServerRow(row);
    _refresh();
  }

  Future<void> delete(String id) async {
    final tenantId = _guard();
    await _ref.read(trackerWriteGatewayProvider).softDelete(tenantId, id);
    await _repo.removeFromCache(id);
    _refresh();
  }

  /// Assign untagged transactions to [trackerId]. No balance moves.
  Future<void> assign(String trackerId, List<String> ids) async {
    final tenantId = _guard();
    if (ids.isEmpty) return;
    await _ref
        .read(trackerWriteGatewayProvider)
        .assign(tenantId, trackerId, ids);
    await _ref
        .read(transactionsRepositoryProvider)
        .setTrackerIdLocally(ids, trackerId);
    _refresh();
  }

  Future<void> unassign(String transactionId) async {
    final tenantId = _guard();
    await _ref
        .read(trackerWriteGatewayProvider)
        .unassign(tenantId, transactionId);
    await _ref
        .read(transactionsRepositoryProvider)
        .setTrackerIdLocally([transactionId], null);
    _refresh();
  }

  TrackersRepository get _repo => _ref.read(trackersRepositoryProvider);

  void _refresh() => _ref.invalidate(trackerSpendRowsProvider);

  String _guard() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();

    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (_ref.read(menuStatusProvider(FeatureMenu.trackers)) ==
        MenuStatus.locked) {
      throw const PermissionFailure(
        message: 'Trackers isn\'t available in this workspace.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }
}

final trackerEditorControllerProvider = Provider<TrackerEditorController>(
  (ref) => TrackerEditorController(ref),
  name: 'trackerEditorController',
);
