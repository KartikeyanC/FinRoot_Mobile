import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/app_config.dart';
import '../../../core/device/device_prefs.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../workspace/application/workspace_providers.dart';
import 'sync_engine.dart';

/// OS-scheduled background sync.
///
/// ⚠️ Device-unverified (no Android SDK / iOS toolchain on the build machine —
/// M2 I-1). The foreground triggers in `SyncCoordinator` (connectivity, resume,
/// realtime, sign-in) cover the common cases; this is the "app fully closed"
/// backstop and needs a real device run plus the Android/iOS native setup
/// (WorkManager is auto-registered by the plugin; iOS needs the BGTaskScheduler
/// identifier in Info.plist — see the M5 report).
const _uniqueName = 'finroot-periodic-sync';
const _taskName = 'finroot.sync.periodic';

@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) => _runBackgroundSync());
}

/// Registered from `bootstrap()`.
Future<void> initBackgroundSync() async {
  try {
    await Workmanager().initialize(syncCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _uniqueName,
      _taskName,
      frequency: const Duration(hours: 1),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } on Object catch (e) {
    // A platform without WorkManager (or an unconfigured build) must not crash
    // startup — the foreground triggers still work.
    AppLog.of('sync.bg')
        .warning('background sync not registered: ${e.runtimeType}');
  }
}

Future<bool> _runBackgroundSync() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.init();
  final log = AppLog.of('sync.bg');
  ProviderContainer? container;
  try {
    final config = AppConfig.fromEnvironment();
    if (!config.isConfigured) return false;
    await initSupabase(config);

    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    // initSupabase restored any stored session from the keystore.
    if (!container.read(isSignedInProvider)) return true;

    await container.read(membershipsProvider.future);
    if (container.read(currentTenantIdProvider) == null) return true;

    await container.read(syncEngineProvider.notifier).syncNow();
    log.info('background sync run complete');
    return true;
  } on Object catch (e) {
    log.warning('background sync failed: ${e.runtimeType}');
    return false; // WorkManager retries per its own policy
  } finally {
    container?.dispose();
  }
}
