import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/features/app_lock/app_lock.dart';
import 'package:finroot_mobile/features/privacy/income_privacy.dart'
    show UnlockResult;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements DeviceLockAuthenticator {
  _Auth(this.result);
  UnlockResult result;
  int calls = 0;
  @override
  Future<UnlockResult> authenticate(String reason) async {
    calls++;
    return result;
  }
}

class _Clock {
  DateTime now = DateTime(2026, 11, 26, 10);
}

Future<ProviderContainer> _container({
  Map<String, Object> prefs = const {},
  MemoryPinVault? vault,
  _Auth? auth,
  _Clock? clock,
  bool signedIn = true,
  bool quickAdd = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final c = clock ?? _Clock();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(p),
      pinVaultProvider.overrideWithValue(vault ?? MemoryPinVault()),
      deviceLockAuthenticatorProvider.overrideWithValue(
        auth ?? _Auth(UnlockResult.ok),
      ),
      appLockClockProvider.overrideWithValue(() => c.now),
      appLockSignedInProvider.overrideWithValue(signedIn),
      isQuickAddEngineProvider.overrideWithValue(quickAdd),
      pinIterationsProvider.overrideWithValue(50),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldLockOnReturn', () {
    final t0 = DateTime(2026, 1, 1, 12);

    test('never locks when the app never left', () {
      expect(shouldLockOnReturn(null, t0, 0), isFalse);
      expect(shouldLockOnReturn(null, t0, 5), isFalse);
    });

    test('"Immediately" locks on any return', () {
      expect(shouldLockOnReturn(t0, t0, 0), isTrue);
    });

    test('locks only once the grace period has run out', () {
      const s59 = Duration(seconds: 59);
      expect(shouldLockOnReturn(t0, t0.add(s59), 1), isFalse);
      expect(
        shouldLockOnReturn(t0, t0.add(const Duration(minutes: 1)), 1),
        isTrue,
      );
      expect(
        shouldLockOnReturn(t0, t0.add(const Duration(minutes: 4)), 5),
        isFalse,
      );
      expect(
        shouldLockOnReturn(t0, t0.add(const Duration(minutes: 15)), 15),
        isTrue,
      );
    });

    test('labels', () {
      expect(graceLabel(0), 'Immediately');
      expect(graceLabel(1), 'After 1 minute');
      expect(graceLabel(15), 'After 15 minutes');
    });
  });

  group('AppLockController', () {
    test('off by default, so nothing locks', () async {
      final c = await _container();
      addTearDown(c.dispose);
      final s = c.read(appLockProvider);
      expect(s.mode, AppLockMode.off);
      expect(s.locked, isFalse);
      expect(s.graceMinutes, defaultGraceMinutes);
      expect(s.pinLength, defaultPinLength);
    });

    test('a cold start locks when the lock is on', () async {
      final c = await _container(prefs: {'finroot.lock.mode': 'device'});
      addTearDown(c.dispose);
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('a cold start does not lock when signed out', () async {
      final c = await _container(
        prefs: {'finroot.lock.mode': 'device'},
        signedIn: false,
      );
      addTearDown(c.dispose);
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('the floating Quick Add engine is never locked', () async {
      final c = await _container(
        prefs: {'finroot.lock.mode': 'pin'},
        quickAdd: true,
      );
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      expect(c.read(appLockProvider).locked, isFalse);
      n.lockNow();
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('PIN: stored as a v2 record, right PIN unlocks', () async {
      final vault = MemoryPinVault();
      final c = await _container(vault: vault);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.setPin('4826');
      expect(vault.value, contains('"v":2'));
      expect(vault.value, isNot(contains('4826')));
      expect(c.read(appLockProvider).mode, AppLockMode.pin);
      expect(c.read(appLockProvider).pinLength, 4);

      n.lockNow();
      expect(await n.submitPin('1111'), PinCheck.wrong);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(c.read(appLockProvider).failedAttempts, 1);
      expect(await n.submitPin('4826'), PinCheck.ok);
      expect(c.read(appLockProvider).locked, isFalse);
      expect(c.read(appLockProvider).failedAttempts, 0);
    });

    test(
      'five wrong PINs pause entry for 30 s, kept across a restart',
      () async {
        final clock = _Clock();
        final vault = MemoryPinVault();
        final c = await _container(vault: vault, clock: clock);
        addTearDown(c.dispose);
        final n = c.read(appLockProvider.notifier);
        await n.setPin('482913');
        n.lockNow();
        for (var i = 0; i < maxPinAttempts - 1; i++) {
          expect(await n.submitPin('000000'), PinCheck.wrong);
        }
        expect(await n.submitPin('000000'), PinCheck.waiting);
        // Even the right PIN waits.
        expect(await n.submitPin('482913'), PinCheck.waiting);
        expect(
          c.read(sharedPreferencesProvider).getInt('finroot.lock.waitUntil'),
          isNotNull,
        );

        clock.now = clock.now.add(pinCooldown);
        expect(await n.submitPin('482913'), PinCheck.ok);
        expect(c.read(appLockProvider).waitUntil, isNull);
      },
    );

    test('device lock: turning on checks the phone lock first', () async {
      final auth = _Auth(UnlockResult.noLock);
      final c = await _container(auth: auth);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      expect(await n.useDeviceLock(), UnlockResult.noLock);
      expect(c.read(appLockProvider).mode, AppLockMode.off);

      auth.result = UnlockResult.ok;
      expect(await n.useDeviceLock(), UnlockResult.ok);
      expect(c.read(appLockProvider).mode, AppLockMode.device);

      n.lockNow();
      auth.result = UnlockResult.failed;
      expect(await n.unlockWithDevice(), UnlockResult.failed);
      expect(c.read(appLockProvider).locked, isTrue);
      auth.result = UnlockResult.ok;
      expect(await n.unlockWithDevice(), UnlockResult.ok);
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('switching to Off forgets the PIN', () async {
      final vault = MemoryPinVault();
      final c = await _container(vault: vault);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.setPin('123456');
      await n.turnOff();
      expect(vault.value, isNull);
      expect(c.read(appLockProvider).mode, AppLockMode.off);
    });

    test('background → back: locks only after the grace period', () async {
      final clock = _Clock();
      final c = await _container(
        prefs: {'finroot.lock.mode': 'device', 'finroot.lock.grace': 1},
        clock: clock,
      );
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.unlockWithDevice();
      expect(c.read(appLockProvider).locked, isFalse);

      n.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.now = clock.now.add(const Duration(seconds: 30));
      n.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.read(appLockProvider).locked, isFalse);

      n.didChangeAppLifecycleState(AppLifecycleState.hidden);
      n.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.now = clock.now.add(const Duration(minutes: 2));
      n.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('"Immediately" locks on the way out', () async {
      final c = await _container(
        prefs: {'finroot.lock.mode': 'device', 'finroot.lock.grace': 0},
      );
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.unlockWithDevice();
      n.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('an unknown grace value falls back to the default', () async {
      final c = await _container(prefs: {'finroot.lock.grace': 7});
      addTearDown(c.dispose);
      expect(c.read(appLockProvider).graceMinutes, defaultGraceMinutes);
      await c.read(appLockProvider.notifier).setGrace(15);
      expect(c.read(appLockProvider).graceMinutes, 15);
    });
  });
}
