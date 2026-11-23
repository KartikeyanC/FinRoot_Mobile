import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/device/device_prefs.dart';
import '../../design/design.dart';

/// "Hide income": income amounts show as ₹ •••• until the person proves it is
/// them with the phone's own lock — fingerprint / face, or the phone PIN,
/// pattern or password when there is no biometric (`biometricOnly: false`).
/// Same feature as the web (`src/lib/incomePrivacy.ts`).
///
/// The hidden choice is per device (SharedPreferences). A reveal lasts until
/// the app goes to the background or [revealFor] passes, so a phone left on a
/// table re-hides itself.
///
/// ⚠️ A curtain, not access control: the numbers are still in the account.
const revealFor = Duration(minutes: 5);
const kIncomeMask = '₹ ••••';
const _kHidden = 'finroot.income.hidden';

class IncomePrivacy {
  const IncomePrivacy({this.hidden = false, this.revealed = false});
  final bool hidden;
  final bool revealed;

  /// True when income amounts must be shown as [kIncomeMask].
  bool get masked => hidden && !revealed;
}

/// What happened when the person asked to see their income.
enum UnlockResult { ok, failed, noLock }

/// Asks the phone's lock. Overridden in tests.
abstract class IncomeUnlocker {
  Future<UnlockResult> unlock();
}

class DeviceIncomeUnlocker implements IncomeUnlocker {
  DeviceIncomeUnlocker([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<UnlockResult> unlock() async {
    try {
      if (!await _auth.isDeviceSupported()) return UnlockResult.noLock;
      final ok = await _auth.authenticate(
        localizedReason: 'Confirm it\'s you to show your income',
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

final incomeUnlockerProvider = Provider<IncomeUnlocker>(
  (ref) => DeviceIncomeUnlocker(),
  name: 'incomeUnlocker',
);

class IncomePrivacyController extends Notifier<IncomePrivacy>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  IncomePrivacy build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    return IncomePrivacy(hidden: _prefs()?.getBool(_kHidden) ?? false);
  }

  /// Device prefs, or null where none were provided (widget tests, the
  /// quick-add pop-up engine): hiding then lasts for this run only.
  SharedPreferences? _prefs() {
    try {
      return ref.read(sharedPreferencesProvider);
    } on Object {
      return null;
    }
  }

  /// Hide income now. Needs no proof.
  Future<void> hide() async {
    _timer?.cancel();
    state = const IncomePrivacy(hidden: true);
    await _prefs()?.setBool(_kHidden, true);
  }

  /// Stop hiding altogether. Only offered while income is already revealed,
  /// i.e. after the person proved it is them.
  Future<void> stopHiding() async {
    _timer?.cancel();
    state = const IncomePrivacy();
    await _prefs()?.setBool(_kHidden, false);
  }

  /// Asks for the fingerprint / phone lock and reveals on success.
  Future<UnlockResult> reveal() async {
    final r = await ref.read(incomeUnlockerProvider).unlock();
    if (r == UnlockResult.ok) {
      _timer?.cancel();
      _timer = Timer(revealFor, hideAgain);
      state = IncomePrivacy(hidden: state.hidden, revealed: true);
    }
    return r;
  }

  void hideAgain() {
    _timer?.cancel();
    if (state.revealed) state = IncomePrivacy(hidden: state.hidden);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      hideAgain();
    }
  }
}

final incomePrivacyProvider =
    NotifierProvider<IncomePrivacyController, IncomePrivacy>(
      IncomePrivacyController.new,
      name: 'incomePrivacy',
    );

/// [text] for an income amount, or [kIncomeMask] while income is hidden.
String incomeText(WidgetRef ref, String text) =>
    ref.watch(incomePrivacyProvider).masked ? kIncomeMask : text;

/// The eye button: hides income at once; showing it asks for the fingerprint
/// or phone lock. While shown, a long-press stops hiding for good.
class IncomePrivacyButton extends ConsumerWidget {
  const IncomePrivacyButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(incomePrivacyProvider);
    final c = ref.read(incomePrivacyProvider.notifier);
    return IconButton(
      key: const ValueKey('income-privacy'),
      tooltip: p.masked ? 'Show income' : 'Hide income',
      icon: Icon(
        p.masked ? Icons.visibility_off_rounded : Icons.visibility_rounded,
      ),
      onPressed: () async {
        if (!p.masked) {
          if (p.hidden) {
            c.hideAgain();
          } else {
            await c.hide();
          }
          return;
        }
        final r = await c.reveal();
        if (!context.mounted) return;
        final msg = switch (r) {
          UnlockResult.ok => null,
          UnlockResult.failed => 'Not confirmed. Income stays hidden.',
          UnlockResult.noLock =>
            'Set a screen lock (fingerprint or PIN) on this phone to show '
                'hidden income.',
        };
        if (msg != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
        }
      },
      onLongPress: p.hidden && !p.masked
          ? () async {
              await c.stopHiding();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Income is no longer hidden')),
              );
            }
          : null,
      color: context.palette.ink,
    );
  }
}
