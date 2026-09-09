import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/database_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/mutation_gateway.dart';
import '../data/pull_gateway.dart';
import '../domain/backoff.dart';
import '../domain/sync_types.dart';
import 'delta_puller.dart';
import 'outbox_processor.dart';

final syncEngineProvider = NotifierProvider<SyncEngine, SyncSnapshot>(
  SyncEngine.new,
  name: 'syncEngine',
);

/// Orchestrates one sync: **push** the outbox, then **pull** deltas. Holds the
/// [SyncSnapshot] the UI watches (offline banner, pending badge, last-synced).
///
/// Guards: one run at a time; a self-imposed cool-off (`_nextAllowedAt`) after a
/// retryable failure so connectivity flapping cannot spin it.
class SyncEngine extends Notifier<SyncSnapshot> {
  @override
  SyncSnapshot build() => const SyncSnapshot();

  final _log = AppLog.of('sync');
  final _backoff = const Backoff();

  bool _running = false;
  DateTime? _nextAllowedAt;
  int _retryRuns = 0;

  OutboxProcessor _outbox() => OutboxProcessor(
    ref.read(appDatabaseProvider),
    ref.read(mutationGatewayProvider),
  );

  DeltaPuller _puller() =>
      DeltaPuller(ref.read(appDatabaseProvider), ref.read(pullGatewayProvider));

  /// Run a sync. [full] ignores cursors and prunes; [force] bypasses the
  /// cool-off. Never throws.
  Future<void> syncNow({bool full = false, bool force = false}) async {
    if (_running) return;
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;

    if (!ref.read(isOnlineProvider)) {
      await _finish(SyncPhase.offline);
      return;
    }
    if (!force &&
        _nextAllowedAt != null &&
        DateTime.now().isBefore(_nextAllowedAt!)) {
      _log.info('sync skipped — cooling off until $_nextAllowedAt');
      return;
    }

    _running = true;
    try {
      state = state.copyWith(phase: SyncPhase.pushing, clearError: true);
      final push = await _outbox().run();

      if (push.backendMissing) {
        _cooldown(1);
        await _finish(SyncPhase.failed, error: push.lastError);
        return;
      }
      if (push.stopped && push.lastError != null) {
        _retryRuns++;
        _cooldown(_retryRuns);
        await _finish(SyncPhase.failed, error: push.lastError);
        return;
      }
      _retryRuns = 0;
      _nextAllowedAt = null;

      state = state.copyWith(phase: SyncPhase.pulling);
      await _puller().run(tenantId, full: full);

      await _finish(SyncPhase.done, syncedNow: true);
    } on Failure catch (f) {
      _retryRuns++;
      _cooldown(_retryRuns);
      await _finish(SyncPhase.failed, error: f.message);
    } catch (error, stack) {
      _retryRuns++;
      _cooldown(_retryRuns);
      await _finish(SyncPhase.failed, error: mapError(error, stack).message);
    } finally {
      _running = false;
    }
  }

  /// Best-effort push right before sign-out. Short timeout; never throws; a
  /// still-pending entry is fine — the caller wipes the DB next.
  Future<void> flushBeforeSignOut({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_running || !ref.read(isOnlineProvider)) return;
    if (ref.read(currentTenantIdProvider) == null) return;
    try {
      await _outbox().run().timeout(timeout);
    } on Object catch (e) {
      _log.warning('pre-sign-out flush did not finish: ${e.runtimeType}');
    }
  }

  /// User tapped "retry" on failed items.
  Future<void> retryFailed() async {
    await ref.read(appDatabaseProvider).syncOutboxDao.requeueFailed();
    await syncNow(force: true);
  }

  void _cooldown(int attempt) {
    _nextAllowedAt = DateTime.now().add(_backoff.ceilingFor(attempt));
  }

  Future<void> _finish(
    SyncPhase phase, {
    String? error,
    bool syncedNow = false,
  }) async {
    final dao = ref.read(appDatabaseProvider).syncOutboxDao;
    final pending = await dao.countPending();
    final failed = await dao.countFailed();
    state = state.copyWith(
      phase: phase,
      pendingCount: pending,
      failedCount: failed,
      lastSyncedAt: syncedNow ? DateTime.now() : null,
      lastError: error,
      clearError: error == null && phase != SyncPhase.offline,
    );
  }
}

/// Live count of everything waiting to reach the server — for a badge on the
/// nav / a status line.
final unsyncedCountProvider = StreamProvider<int>((ref) {
  return ref.watch(appDatabaseProvider).syncOutboxDao.watchUnsyncedCount();
}, name: 'unsyncedCount');
