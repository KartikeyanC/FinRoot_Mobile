import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device/device_prefs.dart';
import '../../core/providers/providers.dart';
import '../privacy/income_privacy.dart' show UnlockResult;
import '../quick_add/presentation/floating_quick_add_screen.dart'
    show floatingQuickAddPath;
import 'pin_record.dart';

/// App lock — the phone side of the web's optional lock (`appLock.ts`,
/// Stage 5.4). Optional; the person picks one of:
///  * [AppLockMode.off] — no lock (the default);
///  * [AppLockMode.device] — the phone's own fingerprint / face / screen lock
///    (local_auth, device credential allowed);
///  * [AppLockMode.pin] — a FinRoot PIN, 4–6 digits (6 by default), stored as
///    a PBKDF2 [PinRecord] in the platform keystore.
///
/// It locks on a cold start when on, and on return from the background once
/// the grace period ([graceOptions]) has run out. A forgotten PIN is reset by
/// signing out and signing in again — the account password is the credential
/// that actually protects the data — and signing out clears the lock.
///
/// ⚠️ A curtain over the screen, not access control. Nothing is encrypted by
/// it, and it cannot stop someone who has the account password. RLS on the
/// server is the real gate. Say so in any UI that mentions it.
enum AppLockMode { off, device, pin }

/// Minutes the app may sit in the background before it locks. 0 = lock on
/// the way out. Same options and default as the web.
const graceOptions = [0, 1, 5, 15];
const defaultGraceMinutes = 5;

const minPinLength = 4;
const maxPinLength = 6;
const defaultPinLength = 6;

/// Wrong PINs allowed before a pause, and how long the pause is.
const maxPinAttempts = 5;
const pinCooldown = Duration(seconds: 30);

String graceLabel(int minutes) => switch (minutes) {
  <= 0 => 'Immediately',
  1 => 'After 1 minute',
  _ => 'After $minutes minutes',
};

/// Should coming back from the background put the lock up? Pure, so the rule
/// can be tested without a device. No [hiddenAt] means the app never left —
/// never lock on that, or a stray lifecycle event would lock someone who
/// never went away.
bool shouldLockOnReturn(DateTime? hiddenAt, DateTime now, int graceMinutes) {
  if (hiddenAt == null) return false;
  if (graceMinutes <= 0) return true;
  return now.difference(hiddenAt) >= Duration(minutes: graceMinutes);
}

// ---- storage ---------------------------------------------------------------

const _kMode = 'finroot.lock.mode';
const _kGrace = 'finroot.lock.grace';
const _kPinLength = 'finroot.lock.pinlen';
const _kWaitUntil = 'finroot.lock.waitUntil';
const _kPinRecord = 'finroot.lock.pin';

/// Where the PIN record lives: the platform keystore on a device, memory in
/// tests.
abstract class PinVault {
  Future<String?> read();
  Future<void> write(String record);
  Future<void> delete();
}

class SecurePinVault implements PinVault {
  const SecurePinVault([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _kPinRecord);
  @override
  Future<void> write(String record) =>
      _storage.write(key: _kPinRecord, value: record);
  @override
  Future<void> delete() => _storage.delete(key: _kPinRecord);
}

class MemoryPinVault implements PinVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String record) async => value = record;
  @override
  Future<void> delete() async => value = null;
}

final pinVaultProvider = Provider<PinVault>(
  (ref) => const SecurePinVault(),
  name: 'pinVault',
);

/// Asks the phone's own lock. Overridden in tests.
abstract class DeviceLockAuthenticator {
  Future<UnlockResult> authenticate(String reason);
}

class LocalAuthAuthenticator implements DeviceLockAuthenticator {
  LocalAuthAuthenticator([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<UnlockResult> authenticate(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.noLock;
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      return ok ? UnlockResult.ok : UnlockResult.failed;
    } on LocalAuthException catch (e) {
      return e.code == LocalAuthExceptionCode.noCredentialsSet ||
              e.code == LocalAuthExceptionCode.noBiometricHardware
          ? UnlockResult.noLock
          : UnlockResult.failed;
    } on PlatformException {
      return UnlockResult.failed;
    }
  }
}

final deviceLockAuthenticatorProvider = Provider<DeviceLockAuthenticator>(
  (ref) => LocalAuthAuthenticator(),
  name: 'deviceLockAuthenticator',
);

/// The Android side of the lock (MainActivity, channel `finroot/app_lock`):
///  * [setHideInRecents] — keep the app's content out of the recent-apps
///    thumbnail while the lock is on (API 33+: no Recents screenshot; below
///    that FLAG_SECURE only while the app is in the background, so
///    screenshots in normal use still work);
///  * [moveToBack] — send the app to the background, keeping it alive, as
///    back on the lock screen does.
/// Overridden in tests. Every call is best-effort: another platform, or an
/// engine with no channel, simply does nothing.
class AppLockPlatform {
  const AppLockPlatform([this._channel = const MethodChannel(channelName)]);
  static const channelName = 'finroot/app_lock';
  final MethodChannel _channel;

  Future<void> setHideInRecents(bool hide) async {
    try {
      await _channel.invokeMethod<void>('setHideInRecents', hide);
    } on MissingPluginException {
      // Not Android / not MainActivity.
    } on PlatformException {
      // Best-effort.
    }
  }

  /// Backgrounds the app; falls back to [SystemNavigator.pop] where the
  /// channel is missing.
  Future<void> moveToBack() async {
    try {
      await _channel.invokeMethod<void>('moveToBack');
    } on MissingPluginException {
      await SystemNavigator.pop();
    } on PlatformException {
      await SystemNavigator.pop();
    }
  }
}

final appLockPlatformProvider = Provider<AppLockPlatform>(
  (ref) => const AppLockPlatform(),
  name: 'appLockPlatform',
);

/// PBKDF2 cost for new records; lowered in tests only.
final pinIterationsProvider = Provider<int>(
  (ref) => PinRecord.currentIterations,
  name: 'pinIterations',
);

/// "now", overridable so tests can move time.
final appLockClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  name: 'appLockClock',
);

/// True in the floating Quick Add engine (QuickAddDialogActivity starts the
/// same Dart app at `/quick-add-float`). That engine is NEVER locked: it can
/// only add an entry — it shows no balances or history — and a lock in front
/// of a two-second "log what I just paid" would defeat it.
final isQuickAddEngineProvider = Provider<bool>(
  (ref) => PlatformDispatcher.instance.defaultRouteName.startsWith(
    floatingQuickAddPath,
  ),
  name: 'isQuickAddEngine',
);

/// Signed in, or false where there is no Supabase client (widget tests).
/// The seam the lock listens to.
final appLockSignedInProvider = Provider<bool>((ref) {
  try {
    return ref.watch(isSignedInProvider);
  } on Object {
    return false;
  }
}, name: 'appLockSignedIn');

// ---- state -----------------------------------------------------------------

class AppLockState {
  const AppLockState({
    this.mode = AppLockMode.off,
    this.graceMinutes = defaultGraceMinutes,
    this.pinLength = defaultPinLength,
    this.locked = false,
    this.failedAttempts = 0,
    this.waitUntil,
  });

  final AppLockMode mode;
  final int graceMinutes;
  final int pinLength;
  final bool locked;
  final int failedAttempts;

  /// While set and in the future, PIN entry is paused.
  final DateTime? waitUntil;

  bool get enabled => mode != AppLockMode.off;

  AppLockState copyWith({
    AppLockMode? mode,
    int? graceMinutes,
    int? pinLength,
    bool? locked,
    int? failedAttempts,
    DateTime? waitUntil,
    bool clearWait = false,
  }) => AppLockState(
    mode: mode ?? this.mode,
    graceMinutes: graceMinutes ?? this.graceMinutes,
    pinLength: pinLength ?? this.pinLength,
    locked: locked ?? this.locked,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    waitUntil: clearWait ? null : (waitUntil ?? this.waitUntil),
  );
}

/// What happened to one PIN attempt.
enum PinCheck { ok, wrong, waiting }

class AppLockController extends Notifier<AppLockState>
    with WidgetsBindingObserver {
  DateTime? _hiddenAt;

  /// True while the phone's own lock prompt is up: its activity sends the
  /// app to the background, which must not count as leaving.
  bool _authenticating = false;

  @override
  AppLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));

    // Session transitions. A restored session at cold start is not a
    // sign-in (cf. web BUG-090: gotrue fires `signedIn` from session
    // recovery too), so only an observed signed-out → signed-in change
    // counts as the password having been typed.
    ref.listen<bool>(appLockSignedInProvider, (prev, next) {
      if (prev == true && !next) {
        // Signed out: the lock belonged to that session. Clearing it is the
        // forgotten-PIN path (sign out, sign in again) and means the next
        // person on this phone does not inherit someone else's PIN.
        unawaited(_clearAll());
      } else if (prev == false && next) {
        state = state.copyWith(locked: false, failedAttempts: 0);
      }
    });

    final p = _prefs();
    final mode = switch (p?.getString(_kMode)) {
      'device' => AppLockMode.device,
      'pin' => AppLockMode.pin,
      _ => AppLockMode.off,
    };
    final grace = p?.getInt(_kGrace);
    final len = p?.getInt(_kPinLength);
    final wait = p?.getInt(_kWaitUntil);
    final signedIn = ref.read(appLockSignedInProvider);
    final quickAdd = _isQuickAdd();
    // Recents thumbnail: set at start, and again whenever the lock is turned
    // on or off. The Quick Add engine is never locked, and has no channel.
    if (!quickAdd) {
      unawaited(_platform()?.setHideInRecents(mode != AppLockMode.off));
      listenSelf((prev, next) {
        if (prev != null && prev.enabled != next.enabled) {
          unawaited(_platform()?.setHideInRecents(next.enabled));
        }
      });
    }
    return AppLockState(
      mode: mode,
      graceMinutes: graceOptions.contains(grace) ? grace! : defaultGraceMinutes,
      pinLength: len != null && len >= minPinLength && len <= maxPinLength
          ? len
          : defaultPinLength,
      locked: mode != AppLockMode.off && signedIn && !quickAdd,
      waitUntil: wait == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(wait),
    );
  }

  bool _isQuickAdd() {
    try {
      return ref.read(isQuickAddEngineProvider);
    } on Object {
      return false;
    }
  }

  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }

  AppLockPlatform? _platform() {
    try {
      return ref.read(appLockPlatformProvider);
    } on Object {
      return null;
    }
  }

  DateTime _now() => ref.read(appLockClockProvider)();

  // ---- settings -----------------------------------------------------------

  /// Turns the lock off and forgets the PIN.
  Future<void> turnOff() async {
    await ref.read(pinVaultProvider).delete();
    await _prefs()?.setString(_kMode, 'off');
    state = state.copyWith(mode: AppLockMode.off, locked: false);
  }

  /// Uses the phone's own lock. Checks it once first, so nobody turns on a
  /// lock their phone cannot answer.
  Future<UnlockResult> useDeviceLock() async {
    final r = await _deviceAuth('Confirm it\'s you to turn on the app lock');
    if (r != UnlockResult.ok) return r;
    await ref.read(pinVaultProvider).delete();
    await _prefs()?.setString(_kMode, 'device');
    state = state.copyWith(mode: AppLockMode.device);
    return r;
  }

  /// Sets (or changes) the FinRoot PIN and switches the lock to it.
  Future<void> setPin(String pin) async {
    assert(RegExp(r'^\d{4,6}$').hasMatch(pin), 'PIN must be 4–6 digits');
    final record = await PinRecord.create(
      pin,
      iterations: ref.read(pinIterationsProvider),
    );
    await ref.read(pinVaultProvider).write(record.encode());
    await _prefs()?.setString(_kMode, 'pin');
    await _prefs()?.setInt(_kPinLength, pin.length);
    state = state.copyWith(mode: AppLockMode.pin, pinLength: pin.length);
  }

  Future<void> setGrace(int minutes) async {
    if (!graceOptions.contains(minutes)) return;
    await _prefs()?.setInt(_kGrace, minutes);
    state = state.copyWith(graceMinutes: minutes);
  }

  // ---- unlocking ----------------------------------------------------------

  /// Checks a typed PIN. After [maxPinAttempts] wrong ones, entry pauses for
  /// [pinCooldown] (kept across a restart).
  Future<PinCheck> submitPin(String pin) async {
    final now = _now();
    final wait = state.waitUntil;
    if (wait != null && now.isBefore(wait)) return PinCheck.waiting;

    final record = PinRecord.tryParse(await ref.read(pinVaultProvider).read());
    final ok = record != null && await record.verify(pin);
    if (ok) {
      if (record.iterations < ref.read(pinIterationsProvider)) {
        await setPin(pin);
      }
      await _prefs()?.remove(_kWaitUntil);
      state = state.copyWith(locked: false, failedAttempts: 0, clearWait: true);
      return PinCheck.ok;
    }

    final failed = state.failedAttempts + 1;
    if (failed >= maxPinAttempts) {
      final until = now.add(pinCooldown);
      await _prefs()?.setInt(_kWaitUntil, until.millisecondsSinceEpoch);
      state = state.copyWith(failedAttempts: 0, waitUntil: until);
      return PinCheck.waiting;
    }
    state = state.copyWith(failedAttempts: failed);
    return PinCheck.wrong;
  }

  /// Unlocks with the phone's own lock.
  Future<UnlockResult> unlockWithDevice() async {
    final r = await _deviceAuth('Unlock FinRoot');
    if (r == UnlockResult.ok) {
      state = state.copyWith(locked: false, failedAttempts: 0);
    }
    return r;
  }

  Future<UnlockResult> _deviceAuth(String reason) async {
    _authenticating = true;
    try {
      return await ref
          .read(deviceLockAuthenticatorProvider)
          .authenticate(reason);
    } finally {
      _authenticating = false;
      _hiddenAt = null;
    }
  }

  /// Puts the lock up now (e.g. "Lock now"); a no-op when the lock is off.
  void lockNow() {
    if (state.enabled && !_isQuickAdd()) {
      state = state.copyWith(locked: true);
    }
  }

  Future<void> _clearAll() async {
    await ref.read(pinVaultProvider).delete();
    final p = _prefs();
    await p?.remove(_kMode);
    await p?.remove(_kPinLength);
    await p?.remove(_kWaitUntil);
    _hiddenAt = null;
    state = AppLockState(graceMinutes: state.graceMinutes);
  }

  // ---- back button --------------------------------------------------------
  //
  // While locked, back must not reach the router: the app underneath would
  // pop routes behind the curtain. A PopScope cannot do this — AppLockGate
  // sits in MaterialApp.router's builder, above the Navigator, and PopScope
  // only registers with an enclosing route. So the controller answers the
  // system back itself. WidgetsBinding asks observers in the order they were
  // added; this one is added when the gate first builds, before the Router
  // (the gate's child) subscribes its back-button dispatcher, so it is asked
  // first. Unlocked, it answers false and the router handles back as usual.
  //
  // On the lock screen, back sends FinRoot to the background (moveTaskToBack)
  // — as banking and other lock apps do — instead of doing nothing (which
  // feels broken) or finishing the activity (which throws away where the
  // person was and makes the next open a cold start).

  @override
  Future<bool> didPopRoute() async {
    if (!state.locked) return false;
    await _platform()?.moveToBack();
    return true;
  }

  /// Predictive back (if ever enabled): claim the gesture while locked so it
  /// never animates the route underneath, and background on commit.
  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) => state.locked;

  @override
  void handleCommitBackGesture() {
    if (state.locked) unawaited(_platform()?.moveToBack());
  }

  // ---- lifecycle ----------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lifecycle = state;
    final lock = this.state;
    if (_authenticating || !lock.enabled) return;
    if (lifecycle == AppLifecycleState.hidden ||
        lifecycle == AppLifecycleState.paused) {
      _hiddenAt ??= _now();
      // "Immediately" locks on the way out, so the task switcher shows the
      // lock screen rather than balances (as far as the OS snapshot allows).
      if (lock.graceMinutes <= 0) lockNow();
    } else if (lifecycle == AppLifecycleState.resumed) {
      if (shouldLockOnReturn(_hiddenAt, _now(), lock.graceMinutes)) {
        lockNow();
      }
      _hiddenAt = null;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
  name: 'appLock',
);
