import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/logging/app_logger.dart';
import '../domain/planned_notification.dart';

/// Schedules on-device notifications. A seam so the coordinator and its tests
/// never touch the platform plugin.
abstract interface class NotificationService {
  /// Prepare the platform plugin + timezone database. Safe to call repeatedly.
  Future<void> init();

  /// Ask the OS for permission to post notifications (Android 13+, iOS, macOS).
  /// Returns true if granted (or not required).
  Future<bool> requestPermission();

  /// Make the OS schedule exactly [plan] — cancels everything this app
  /// scheduled, then re-adds each entry. Idempotent.
  Future<void> reconcile(List<PlannedNotification> plan);

  /// Drop every scheduled notification (used on sign-out).
  Future<void> cancelAll();

  /// Post a notification right now (a price alert that just fired). Separate
  /// channel and ids from the schedule, so [reconcile] never cancels it.
  Future<void> showNow({required int id, required String title, required String body});
}

/// Real implementation over `flutter_local_notifications`.
///
/// ⚠️ **Device-unverified** (M12), the same status `workmanager` carried at M5:
/// the Android receivers / `POST_NOTIFICATIONS` / `SCHEDULE_EXACT_ALARM`
/// wiring and the iOS categories are added to the native projects but cannot
/// be exercised without an Android SDK / device. The in-app "Upcoming" card is
/// the primary, tested surface; scheduled notifications are best-effort until a
/// device run.
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final _log = AppLog.of('notifications');
  bool _ready = false;

  static const _channelId = 'finroot_schedule';
  static const _channelName = 'Upcoming payments & reminders';

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (error, stack) {
      _log.warning('init failed (device-unverified)', error, stack);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      return true;
    } catch (error, stack) {
      _log.warning('permission request failed', error, stack);
      return false;
    }
  }

  @override
  Future<void> reconcile(List<PlannedNotification> plan) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Alerts before a recurring item is due or a reminder lands',
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      for (final n in plan) {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.fireAt, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
      _log.info('reconciled ${plan.length} notification(s)');
    } catch (error, stack) {
      _log.warning('reconcile failed (device-unverified)', error, stack);
    }
  }

  static const _alertChannelId = 'finroot_price_alerts';
  static const _alertChannelName = 'Price alerts';

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _alertChannelId,
            _alertChannelName,
            channelDescription: 'When a stock reaches the price you set',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (error, stack) {
      _log.warning('showNow failed', error, stack);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (error, stack) {
      _log.warning('cancelAll failed', error, stack);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => LocalNotificationService(),
  name: 'notificationService',
);
