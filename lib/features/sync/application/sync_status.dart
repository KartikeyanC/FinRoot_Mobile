import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../domain/sync_types.dart';
import 'sync_engine.dart';

/// How the sync engine should read to a person, collapsed to one of five tones.
/// The banner and the header chip both derive from this so they never disagree.
enum SyncTone {
  /// Cache matches the server, nothing waiting.
  synced,

  /// A push or pull is running right now.
  working,

  /// Local changes are queued but sync has not run / finished yet.
  waiting,

  /// No connection — changes are held locally and will go up on reconnect.
  offline,

  /// A sync failed in a way that needs the user (validation, permission).
  problem,
}

/// A UI-ready view of [SyncEngine] state plus connectivity. Watched by
/// `SyncStatusBanner` (app-wide) and `SyncStatusChip` (Home header).
class SyncStatusView {
  const SyncStatusView({
    required this.tone,
    required this.online,
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncTone tone;
  final bool online;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  /// Total changes not yet confirmed by the server.
  int get unsyncedCount => pendingCount + failedCount;

  /// The banner only shows for states a person can or should act on: offline
  /// (informational, persistent) and problem (needs a retry). Everything else
  /// is quiet — the header chip carries it.
  bool get showBanner => tone == SyncTone.offline || tone == SyncTone.problem;

  const SyncStatusView._empty()
    : tone = SyncTone.synced,
      online = true,
      pendingCount = 0,
      failedCount = 0,
      lastSyncedAt = null,
      lastError = null;

  static const empty = SyncStatusView._empty();
}

final syncStatusProvider = Provider<SyncStatusView>((ref) {
  final snap = ref.watch(syncEngineProvider);
  final online = ref.watch(isOnlineProvider);
  final failed = snap.failedCount;
  // `unsyncedCountProvider` streams pending + failed entries (everything not
  // in flight) and is the most live count; fall back to the snapshot until it
  // produces its first value.
  final unsynced = ref.watch(unsyncedCountProvider).value ??
      (snap.pendingCount + failed);
  final pending = (unsynced - failed).clamp(0, unsynced);

  final tone = switch (0) {
    _ when !online => SyncTone.offline,
    _ when snap.phase == SyncPhase.failed || failed > 0 => SyncTone.problem,
    _ when snap.isBusy => SyncTone.working,
    _ when pending > 0 => SyncTone.waiting,
    _ => SyncTone.synced,
  };

  return SyncStatusView(
    tone: tone,
    online: online,
    pendingCount: pending,
    failedCount: failed,
    lastSyncedAt: snap.lastSyncedAt,
    lastError: snap.lastError,
  );
}, name: 'syncStatus');
