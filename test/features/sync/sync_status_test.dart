import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/sync/application/sync_engine.dart';
import 'package:finroot_mobile/features/sync/application/sync_status.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSyncEngine extends SyncEngine {
  _FakeSyncEngine(this._snapshot);
  final SyncSnapshot _snapshot;
  @override
  SyncSnapshot build() => _snapshot;
}

SyncStatusView _view(
  SyncSnapshot snapshot, {
  bool online = true,
  int? unsynced,
}) {
  final container = ProviderContainer(
    overrides: [
      syncEngineProvider.overrideWith(() => _FakeSyncEngine(snapshot)),
      isOnlineProvider.overrideWithValue(online),
      // `loading` → `.value` is null and the view falls back to the snapshot's
      // counts; a number → the live stream has emitted.
      unsyncedCountProvider.overrideWithValue(
        unsynced == null
            ? const AsyncValue<int>.loading()
            : AsyncValue<int>.data(unsynced),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container.read(syncStatusProvider);
}

void main() {
  test('offline wins over everything', () {
    final v = _view(
      const SyncSnapshot(phase: SyncPhase.failed, failedCount: 2),
      online: false,
    );
    expect(v.tone, SyncTone.offline);
    expect(v.showBanner, isTrue);
  });

  test('a failed sync is a problem and shows the banner', () {
    final v = _view(const SyncSnapshot(phase: SyncPhase.failed, failedCount: 1));
    expect(v.tone, SyncTone.problem);
    expect(v.failedCount, 1);
    expect(v.showBanner, isTrue);
  });

  test('busy while online reads as working, no banner', () {
    final v = _view(const SyncSnapshot(phase: SyncPhase.pulling));
    expect(v.tone, SyncTone.working);
    expect(v.showBanner, isFalse);
  });

  test('pending changes with no failure read as waiting', () {
    final v = _view(const SyncSnapshot(pendingCount: 3));
    expect(v.tone, SyncTone.waiting);
    expect(v.pendingCount, 3);
    expect(v.showBanner, isFalse);
  });

  test('idle and clean reads as synced', () {
    final v = _view(
      SyncSnapshot(phase: SyncPhase.done, lastSyncedAt: DateTime(2026, 9, 9)),
    );
    expect(v.tone, SyncTone.synced);
    expect(v.lastSyncedAt, isNotNull);
  });

  test('the live unsynced count splits into pending vs failed', () {
    // 4 unsynced total, 1 of them failed → 3 still pending.
    final v = _view(const SyncSnapshot(failedCount: 1), unsynced: 4);

    expect(v.failedCount, 1);
    expect(v.pendingCount, 3);
    expect(v.unsyncedCount, 4);
    expect(v.tone, SyncTone.problem); // a failure is present
  });
}
