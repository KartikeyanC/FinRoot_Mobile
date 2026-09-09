import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../recurring/domain/recurring_item.dart';
import '../../recurring/domain/reminder_setting.dart';
import '../../reminders/application/reminders_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../data/notification_service.dart';
import '../domain/planned_notification.dart';

/// Keeps the OS's scheduled notifications in step with recurring items, their
/// bell settings and standalone reminders.
///
/// Recomputes (debounced) whenever any of those change, and on app resume.
/// Clears everything on sign-out. Kept alive by `NotificationScope` near the
/// root, mirroring `SyncScope`.
final notificationCoordinatorProvider =
    NotifierProvider<NotificationCoordinator, void>(
  NotificationCoordinator.new,
  name: 'notificationCoordinator',
);

class NotificationCoordinator extends Notifier<void> {
  final _log = AppLog.of('notifications.coordinator');
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  bool _initialised = false;

  @override
  void build() {
    _lifecycle = AppLifecycleListener(onResume: () => _schedule('resume'));
    ref.onDispose(() {
      _lifecycle?.dispose();
      _debounce?.cancel();
    });

    ref.listen(recurringItemsProvider, (_, _) => _schedule('recurring'));
    ref.listen(recurringRemindersProvider, (_, _) => _schedule('bells'));
    ref.listen(remindersProvider, (_, _) => _schedule('reminders'));

    ref.listen(isSignedInProvider, (_, signedIn) {
      if (!signedIn) {
        _debounce?.cancel();
        unawaited(ref.read(notificationServiceProvider).cancelAll());
      }
    });
  }

  void _schedule(String reason) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      unawaited(_reconcile(reason));
    });
  }

  Future<void> _reconcile(String reason) async {
    if (!ref.read(isSignedInProvider)) return;

    final items =
        ref.read(recurringItemsProvider).value ?? const <RecurringItem>[];
    final bells = ref.read(recurringRemindersProvider).value ??
        const <String, ReminderSetting>{};
    final reminders =
        ref.read(remindersProvider).value ?? const <Reminder>[];

    // Nothing to schedule and nothing pending → skip the platform round-trip.
    final anyBell = bells.values.any((s) => s.enabled);
    if (items.isEmpty && !anyBell && reminders.isEmpty && !_initialised) {
      return;
    }

    final service = ref.read(notificationServiceProvider);
    if (!_initialised) {
      await service.init();
      await service.requestPermission();
      _initialised = true;
    }

    final plan = planNotifications(
      recurringItems: items,
      reminderSettings: bells,
      reminders: reminders,
    );
    _log.info('reconcile ($reason): ${plan.length} scheduled');
    await service.reconcile(plan);
  }
}

/// Mount near the app root to keep the coordinator alive.
class NotificationScope extends ConsumerWidget {
  const NotificationScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationCoordinatorProvider);
    return child;
  }
}
