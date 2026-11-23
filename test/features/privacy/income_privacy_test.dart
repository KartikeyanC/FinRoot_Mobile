import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/features/privacy/income_privacy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Unlocker implements IncomeUnlocker {
  _Unlocker(this.result);
  UnlockResult result;
  int calls = 0;
  @override
  Future<UnlockResult> unlock() async {
    calls++;
    return result;
  }
}

Future<ProviderContainer> _container(_Unlocker u, {bool hidden = false}) async {
  SharedPreferences.setMockInitialValues({'finroot.income.hidden': hidden});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      incomeUnlockerProvider.overrideWithValue(u),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hiding needs no proof and is remembered on the device', () async {
    final u = _Unlocker(UnlockResult.ok);
    final c = await _container(u);
    addTearDown(c.dispose);
    expect(c.read(incomePrivacyProvider).masked, isFalse);
    await c.read(incomePrivacyProvider.notifier).hide();
    expect(c.read(incomePrivacyProvider).masked, isTrue);
    expect(
      c.read(sharedPreferencesProvider).getBool('finroot.income.hidden'),
      isTrue,
    );
    expect(u.calls, 0);
  });

  test('showing asks the phone lock; a failed check keeps it hidden', () async {
    final u = _Unlocker(UnlockResult.failed);
    final c = await _container(u, hidden: true);
    addTearDown(c.dispose);
    final n = c.read(incomePrivacyProvider.notifier);
    expect(await n.reveal(), UnlockResult.failed);
    expect(c.read(incomePrivacyProvider).masked, isTrue);

    u.result = UnlockResult.ok;
    expect(await n.reveal(), UnlockResult.ok);
    expect(c.read(incomePrivacyProvider).masked, isFalse);
    expect(u.calls, 2);

    // Re-hides by itself; the choice to hide stays on.
    n.hideAgain();
    expect(c.read(incomePrivacyProvider).masked, isTrue);
    expect(c.read(incomePrivacyProvider).hidden, isTrue);
  });

  test('going to the background hides income again', () async {
    final c = await _container(_Unlocker(UnlockResult.ok), hidden: true);
    addTearDown(c.dispose);
    final n = c.read(incomePrivacyProvider.notifier);
    await n.reveal();
    n.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(c.read(incomePrivacyProvider).masked, isTrue);
  });
}
