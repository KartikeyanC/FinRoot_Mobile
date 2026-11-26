import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/notifications/application/notification_settings.dart';
import 'package:finroot_mobile/features/notifications/data/notification_permission.dart';
import 'package:finroot_mobile/features/notifications/data/notification_service.dart';
import 'package:finroot_mobile/features/notifications/domain/planned_notification.dart';
import 'package:finroot_mobile/features/notifications/presentation/notification_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePermissions implements NotificationPermissions {
  _FakePermissions(this.allowed);
  bool? allowed;
  int opened = 0;

  @override
  Future<bool?> enabled() async => allowed;

  @override
  Future<void> openSettings() async => opened++;
}

class _FakeService implements NotificationService {
  _FakeService(this.grant);
  final bool grant;
  int asked = 0;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    asked++;
    return grant;
  }

  @override
  Future<void> reconcile(List<PlannedNotification> plan) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Stream<String> get taps => const Stream.empty();

  @override
  Future<String?> launchPayload() async => null;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _FakePermissions permissions,
  required _FakeService service,
}) async {
  // A tall phone, so the whole list (down to the time row) is built.
  tester.view
    ..physicalSize = const Size(1080, 3200)
    ..devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      notificationPermissionsProvider.overrideWithValue(permissions),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light),
        home: const NotificationSettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('toggles and lead pills drive the settings', (tester) async {
    final container = await _pump(
      tester,
      permissions: _FakePermissions(true),
      service: _FakeService(true),
    );

    expect(find.text('Notifications are allowed'), findsOneWidget);
    expect(find.byKey(const ValueKey('notify-allow')), findsNothing);
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.byKey(const ValueKey('notify-subscription-lead')), findsOne);

    await tester.tap(find.byKey(const ValueKey('notify-reminders')));
    await tester.pumpAndSettle();
    expect(container.read(notificationSettingsProvider).reminders, false);

    // Choosing "3 days before" for renewals (the pill row scrolls sideways).
    final threeDays = find.descendant(
      of: find.byKey(const ValueKey('notify-subscription-lead')),
      matching: find.text('3 days before'),
    );
    await tester.ensureVisible(threeDays);
    await tester.pumpAndSettle();
    await tester.tap(threeDays);
    await tester.pumpAndSettle();
    expect(
      container.read(notificationSettingsProvider).subscriptionLeadDays,
      3,
    );

    // Switching renewals off hides their lead picker.
    await tester.tap(find.byKey(const ValueKey('notify-subscriptions')));
    await tester.pumpAndSettle();
    expect(container.read(notificationSettingsProvider).subscriptions, false);
    expect(
      find.byKey(const ValueKey('notify-subscription-lead')),
      findsNothing,
    );
  });

  testWidgets('the time row opens a picker and saves the time', (tester) async {
    final container = await _pump(
      tester,
      permissions: _FakePermissions(true),
      service: _FakeService(true),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('notify-time')));
    await tester.tap(find.byKey(const ValueKey('notify-time')));
    await tester.pumpAndSettle();
    expect(find.text('Remind me at'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      container.read(notificationSettingsProvider).time,
      const TimeOfDay(hour: 9, minute: 0),
    );
  });

  testWidgets('denied → ask, then open the phone settings', (tester) async {
    final permissions = _FakePermissions(false);
    final service = _FakeService(false);
    await _pump(tester, permissions: permissions, service: service);

    expect(find.text('Notifications are off for FinRoot'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('notify-allow')));
    await tester.pumpAndSettle();
    expect(service.asked, 1);
    expect(permissions.opened, 1);
  });

  testWidgets('granted from the prompt → card updates, no settings page', (
    tester,
  ) async {
    final permissions = _FakePermissions(false);
    final service = _FakeService(true);
    await _pump(tester, permissions: permissions, service: service);

    permissions.allowed = true; // what Android reports after the yes
    await tester.tap(find.byKey(const ValueKey('notify-allow')));
    await tester.pumpAndSettle();
    expect(permissions.opened, 0);
    expect(find.text('Notifications are allowed'), findsOneWidget);
  });
}
