import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/config/app_config.dart';
import '../../../core/device/device_prefs.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../investments/data/live_price_gateway.dart';
import '../../notifications/data/notification_service.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/data/notified_alerts_store.dart';
import '../../price_alerts/data/price_alerts_gateway.dart';
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

/// Price alerts get their own, more frequent job: 15 minutes is the shortest
/// period Android allows, and the sync job stays hourly. Android may still
/// stretch both while the phone is in battery saver / Doze.
const _alertsUniqueName = 'finroot-price-alerts';
const _alertsTaskName = 'finroot.price_alerts.check';

@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask(
    (task, inputData) => task == _alertsTaskName
        ? _runBackgroundPriceAlerts()
        : _runBackgroundSync(),
  );
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
    await Workmanager().registerPeriodicTask(
      _alertsUniqueName,
      _alertsTaskName,
      frequency: const Duration(minutes: 15),
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

/// The app may be closed when a stock reaches the price someone set: price
/// the alerts, record triggers, and notify — including triggers another
/// device recorded first.
Future<bool> _runBackgroundPriceAlerts() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.init();
  final log = AppLog.of('price-alerts.bg');
  ProviderContainer? container;
  try {
    final config = AppConfig.fromEnvironment();
    if (!config.isConfigured) return false;
    await initSupabase(config);

    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    if (!container.read(isSignedInProvider)) return true;

    await container.read(membershipsProvider.future);
    final tenantId = container.read(currentTenantIdProvider);
    if (tenantId == null) return true;

    await runPriceAlertCheck(
      tenantId: tenantId,
      userId: container.read(currentUserIdProvider),
      alerts: container.read(priceAlertsGatewayProvider),
      prices: container.read(livePriceGatewayProvider),
      notifications: container.read(notificationServiceProvider),
      notified: container.read(notifiedAlertsStoreProvider),
    );
    return true;
  } on Object catch (e) {
    log.warning('background price alert check failed: ${e.runtimeType}');
    return false;
  } finally {
    container?.dispose();
  }
}
