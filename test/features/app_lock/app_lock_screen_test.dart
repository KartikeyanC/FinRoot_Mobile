import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/app_lock/app_lock.dart';
import 'package:finroot_mobile/features/app_lock/app_lock_screen.dart';
import 'package:finroot_mobile/features/app_lock/pin_record.dart';
import 'package:finroot_mobile/features/privacy/income_privacy.dart'
    show UnlockResult;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements DeviceLockAuthenticator {
  UnlockResult result = UnlockResult.failed;
  @override
  Future<UnlockResult> authenticate(String reason) async => result;
}

class _Clock {
  DateTime now = DateTime(2026, 11, 26, 10);
}

const _pin = '482913';

Future<({_Clock clock, ProviderContainer container})> _pump(
  WidgetTester tester, {
  String mode = 'pin',
  Future<void> Function()? signOut,
  _Auth? auth,
}) async {
  SharedPreferences.setMockInitialValues({
    'finroot.lock.mode': mode,
    'finroot.lock.pinlen': _pin.length,
  });
  final prefs = await SharedPreferences.getInstance();
  final vault = MemoryPinVault();
  final record = await tester.runAsync(
    () => PinRecord.create(_pin, iterations: 50),
  );
  vault.value = record!.encode();
  final clock = _Clock();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pinVaultProvider.overrideWithValue(vault),
      deviceLockAuthenticatorProvider.overrideWithValue(auth ?? _Auth()),
      appLockClockProvider.overrideWithValue(() => clock.now),
      appLockSignedInProvider.overrideWithValue(true),
      isQuickAddEngineProvider.overrideWithValue(false),
      pinIterationsProvider.overrideWithValue(50),
      if (signOut != null) appLockSignOutProvider.overrideWithValue(signOut),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light),
        home: const AppLockGate(child: Scaffold(body: Text('balances'))),
      ),
    ),
  );
  await tester.pump();
  return (clock: clock, container: container);
}

Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('pin-key-$d')));
    await tester.pump();
  }
  // Let the (tiny) KDF finish and the result render.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

String _message(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('app-lock-message'))).data ??
    '';

void main() {
  testWidgets('covers the app on a cold start; the right PIN unlocks', (
    tester,
  ) async {
    final h = await _pump(tester);
    expect(find.text('FinRoot is locked'), findsOneWidget);
    // The app underneath is mounted but hidden from accessibility.
    expect(find.text('balances'), findsOneWidget);
    expect(find.bySemanticsLabel('balances'), findsNothing);

    await _type(tester, _pin);
    expect(h.container.read(appLockProvider).locked, isFalse);
    expect(find.text('FinRoot is locked'), findsNothing);
    expect(find.text('balances'), findsOneWidget);
  });

  testWidgets('a wrong PIN shakes and says how many tries are left', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('pin-key-1')));
    await tester.pump();
    for (final d in '11112'.split('')) {
      await tester.tap(find.byKey(ValueKey('pin-key-$d')));
      await tester.pump();
    }
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    // Mid-shake: the dots are offset from centre.
    await tester.pump(const Duration(milliseconds: 60));
    final shaken = tester
        .widget<Transform>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('app-lock-dots')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .getTranslation()
        .x;
    expect(shaken, isNot(0));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_message(tester), 'Wrong PIN. 4 tries left.');
    expect(h.container.read(appLockProvider).locked, isTrue);
  });

  testWidgets('after 5 wrong tries, entry waits 30 s', (tester) async {
    final h = await _pump(tester);
    for (var i = 0; i < maxPinAttempts; i++) {
      await _type(tester, '000000');
    }
    expect(_message(tester), contains('Try again in 30 s'));

    // Keys do nothing while waiting — even the right PIN.
    await _type(tester, _pin);
    expect(h.container.read(appLockProvider).locked, isTrue);

    h.clock.now = h.clock.now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(_message(tester), contains('Try again in 20 s'));

    h.clock.now = h.clock.now.add(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));
    expect(_message(tester), isNot(contains('Try again')));

    await _type(tester, _pin);
    expect(h.container.read(appLockProvider).locked, isFalse);
  });

  testWidgets('forgotten PIN: sign out clears the lock', (tester) async {
    var signedOut = false;
    final h = await _pump(tester, signOut: () async => signedOut = true);
    await tester.tap(find.byKey(const ValueKey('app-lock-forgot')));
    await tester.pump();
    expect(find.text('Sign out and sign in again'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('app-lock-signout')));
    await tester.pump();
    await tester.pump();
    expect(signedOut, isTrue);
    expect(h.container.read(appLockProvider).mode, AppLockMode.off);
    expect(h.container.read(appLockProvider).locked, isFalse);
    expect(h.container.read(pinVaultProvider), isA<MemoryPinVault>());
    expect(
      (h.container.read(pinVaultProvider) as MemoryPinVault).value,
      isNull,
    );
  });

  testWidgets('device mode asks the phone lock and unlocks on success', (
    tester,
  ) async {
    final auth = _Auth()..result = UnlockResult.failed;
    final h = await _pump(tester, mode: 'device', auth: auth);
    await tester.pump();
    expect(find.text('Not confirmed. Try again.'), findsOneWidget);
    auth.result = UnlockResult.ok;
    await tester.tap(find.byKey(const ValueKey('app-lock-device')));
    await tester.pump();
    await tester.pump();
    expect(h.container.read(appLockProvider).locked, isFalse);
    expect(find.text('FinRoot is locked'), findsNothing);
  });
}
