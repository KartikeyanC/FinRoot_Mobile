import 'dart:async';

import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/app_lock/app_lock.dart';
import 'package:finroot_mobile/features/app_lock/app_lock_screen.dart';
import 'package:finroot_mobile/features/privacy/income_privacy.dart'
    show UnlockResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements DeviceLockAuthenticator {
  UnlockResult result = UnlockResult.ok;
  @override
  Future<UnlockResult> authenticate(String reason) async => result;
}

class _Platform implements AppLockPlatform {
  final hide = <bool>[];
  int movedToBack = 0;
  @override
  Future<void> setHideInRecents(bool value) async => hide.add(value);
  @override
  Future<void> moveToBack() async => movedToBack++;
}

Future<ProviderContainer> _container(
  _Platform platform, {
  String? mode,
  bool quickAdd = false,
  _Auth? auth,
}) async {
  SharedPreferences.setMockInitialValues({'finroot.lock.mode': ?mode});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pinVaultProvider.overrideWithValue(MemoryPinVault()),
      deviceLockAuthenticatorProvider.overrideWithValue(auth ?? _Auth()),
      appLockSignedInProvider.overrideWithValue(true),
      isQuickAddEngineProvider.overrideWithValue(quickAdd),
      pinIterationsProvider.overrideWithValue(50),
      appLockPlatformProvider.overrideWithValue(platform),
    ],
  );
}

/// The system back button, as Android sends it.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hide in Recents', () {
    test('set at start from the saved mode', () async {
      final off = _Platform();
      final c1 = await _container(off);
      addTearDown(c1.dispose);
      c1.read(appLockProvider);
      expect(off.hide, [false]);

      final on = _Platform();
      final c2 = await _container(on, mode: 'pin');
      addTearDown(c2.dispose);
      c2.read(appLockProvider);
      expect(on.hide, [true]);
    });

    test('follows the lock being turned on and off', () async {
      final p = _Platform();
      final c = await _container(p);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.setPin('4826');
      // Locking / unlocking / grace changes do not re-send it.
      n.lockNow();
      await n.setGrace(15);
      await n.useDeviceLock();
      await n.turnOff();
      expect(p.hide, [false, true, false]);
    });

    test('never touched in the floating Quick Add engine', () async {
      final p = _Platform();
      final c = await _container(p, mode: 'pin', quickAdd: true);
      addTearDown(c.dispose);
      c.read(appLockProvider);
      expect(p.hide, isEmpty);
    });

    test('the real channel sends setHideInRecents / moveToBack', () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(AppLockPlatform.channelName);
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const platform = AppLockPlatform();
      await platform.setHideInRecents(true);
      await platform.moveToBack();
      expect(calls.map((c) => c.method), ['setHideInRecents', 'moveToBack']);
      expect(calls.first.arguments, true);
    });

    test('a missing channel is harmless', () async {
      await const AppLockPlatform(
        MethodChannel('finroot/app_lock_missing_for_test'),
      ).setHideInRecents(true);
    });
  });

  group('system back', () {
    Future<({GoRouter router, ProviderContainer container, _Platform p})>
    pumpApp(WidgetTester tester, [_Auth? auth]) async {
      final p = _Platform();
      final container = await _container(p, mode: 'device', auth: auth);
      addTearDown(container.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, _) => const Scaffold(body: Text('detail')),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // Same shape as lib/app/app.dart: the gate in the router's builder.
          child: MaterialApp.router(
            theme: AppTheme.build(Brightness.light),
            routerConfig: router,
            builder: (_, child) => AppLockGate(child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (router: router, container: container, p: p);
    }

    // The top-most route (a pushed one included).
    String location(GoRouter r) => r.state.uri.toString();

    testWidgets('while locked, back leaves the routes alone and backgrounds '
        'the app', (tester) async {
      final auth = _Auth();
      final h = await pumpApp(tester, auth);
      final n = h.container.read(appLockProvider.notifier);
      // The cold-start lock was answered by the (fake) phone lock.
      expect(h.container.read(appLockProvider).locked, isFalse);

      unawaited(h.router.push('/detail'));
      await tester.pumpAndSettle();
      expect(location(h.router), '/detail');

      // The phone lock now says no, so the lock screen stays up.
      auth.result = UnlockResult.failed;
      n.lockNow();
      await tester.pumpAndSettle();
      expect(find.text('FinRoot is locked'), findsOneWidget);

      await _systemBack(tester);
      await _systemBack(tester);
      expect(location(h.router), '/detail');
      expect(find.text('FinRoot is locked'), findsOneWidget);
      expect(h.p.movedToBack, 2);

      // Unlocked, back is the router's again.
      auth.result = UnlockResult.ok;
      await n.unlockWithDevice();
      await tester.pumpAndSettle();
      await _systemBack(tester);
      expect(location(h.router), '/');
      expect(h.p.movedToBack, 2);
    });

    testWidgets('predictive back is claimed only while locked', (tester) async {
      final h = await pumpApp(tester);
      final n = h.container.read(appLockProvider.notifier);
      final event = PredictiveBackEvent.fromMap(const {
        'touchOffset': [0.0, 0.0],
        'progress': 0.0,
        'swipeEdge': 0,
      });
      expect(n.handleStartBackGesture(event), isFalse);
      n.lockNow();
      expect(n.handleStartBackGesture(event), isTrue);
      n.handleCommitBackGesture();
      expect(h.p.movedToBack, 1);
    });
  });
}
