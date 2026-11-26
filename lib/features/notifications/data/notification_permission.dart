import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';

/// Reads whether the OS lets FinRoot post notifications, and opens the
/// phone's notification settings for the app. A seam beside
/// [NotificationService] (which owns *asking*) so the settings screen and its
/// tests never touch the platform plugin.
abstract interface class NotificationPermissions {
  /// True / false on Android; null where the plugin cannot tell (other
  /// platforms, or the call failed).
  Future<bool?> enabled();

  /// Open Android's notification settings page for FinRoot. Needed once the
  /// person has denied the prompt: Android then stops showing it.
  Future<void> openSettings();
}

class LocalNotificationPermissions implements NotificationPermissions {
  LocalNotificationPermissions([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _log = AppLog.of('notifications.permission');

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool?> enabled() async {
    try {
      return await _android?.areNotificationsEnabled();
    } catch (error, stack) {
      _log.warning('permission state unavailable', error, stack);
      return null;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _android?.openAppNotificationSettings();
    } catch (error, stack) {
      _log.warning('could not open notification settings', error, stack);
    }
  }
}

final notificationPermissionsProvider = Provider<NotificationPermissions>(
  (ref) => LocalNotificationPermissions(),
  name: 'notificationPermissions',
);

/// Whether notifications are allowed right now. Invalidate after asking, and
/// when the app comes back from the phone's settings.
final notificationsAllowedProvider = FutureProvider.autoDispose<bool?>(
  (ref) => ref.watch(notificationPermissionsProvider).enabled(),
  name: 'notificationsAllowed',
);
