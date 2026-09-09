import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../workspace/application/workspace_providers.dart';
import 'sync_engine.dart';

/// Decides *when* the [SyncEngine] runs, from ambient signals:
///
/// - signed in + a workspace resolved  → sync (full the first time per session)
/// - connectivity returns              → sync
/// - the app is resumed                → sync
/// - Supabase Realtime reports a change → debounced sync
///
/// Keep it alive by `ref.watch(syncCoordinatorProvider)` in a widget near the
/// root (see `SyncScope`).
final syncCoordinatorProvider = NotifierProvider<SyncCoordinator, void>(
  SyncCoordinator.new,
  name: 'syncCoordinator',
);

class SyncCoordinator extends Notifier<void> {
  final _log = AppLog.of('sync.coordinator');
  final _fullySyncedTenants = <String>{};

  AppLifecycleListener? _lifecycle;
  RealtimeChannel? _channel;
  String? _channelTenant;
  Timer? _debounce;

  @override
  void build() {
    _lifecycle = AppLifecycleListener(onResume: () => _kick(reason: 'resume'));
    ref.onDispose(() {
      _lifecycle?.dispose();
      _debounce?.cancel();
      _teardownChannel();
    });

    // Connectivity: only act on the transition into "online".
    ref.listen(isOnlineProvider, (was, now) {
      if (now && (was ?? false) == false) _kick(reason: 'online');
    });

    // Signed in + workspace resolved → sync, and (re)subscribe realtime.
    ref.listen(currentTenantIdProvider, (_, tenantId) {
      _syncChannel(tenantId);
      if (tenantId != null) {
        final full = _fullySyncedTenants.add(tenantId); // true if newly added
        _kick(reason: 'workspace', full: full);
      }
    }, fireImmediately: true);
  }

  void _kick({required String reason, bool full = false}) {
    if (!ref.read(isSignedInProvider)) return;
    _log.info('sync trigger: $reason${full ? " (full)" : ""}');
    unawaited(ref.read(syncEngineProvider.notifier).syncNow(full: full));
  }

  void _debouncedKick(String reason) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => _kick(reason: reason));
  }

  // ---- Realtime -----------------------------------------------------------

  void _syncChannel(String? tenantId) {
    if (tenantId == _channelTenant) return;
    _teardownChannel();
    if (tenantId == null) return;

    _channelTenant = tenantId;
    final client = ref.read(supabaseClientProvider);
    final channel = client.channel('sync:tenant:$tenantId');
    for (final table in const [
      'transactions',
      'accounts',
      'trackers',
      'budgets',
      'goals',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'tenant_id',
          value: tenantId,
        ),
        callback: (_) => _debouncedKick('realtime'),
      );
    }
    channel.subscribe();
    _channel = channel;
  }

  void _teardownChannel() {
    final ch = _channel;
    if (ch != null) {
      unawaited(ref.read(supabaseClientProvider).removeChannel(ch));
    }
    _channel = null;
    _channelTenant = null;
  }
}

/// Mount near the root so the coordinator lives for the app's lifetime.
class SyncScope extends ConsumerWidget {
  const SyncScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncCoordinatorProvider);
    return child;
  }
}
