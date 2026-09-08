import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local key/value preferences.
///
/// This is NOT the synced store (that is Drift, from M4) and NOT the secret
/// store (that is the keystore, `secure_local_storage.dart`). It holds choices
/// that are per-device by design — theme, the last-selected workspace, and
/// later onboarding flags / last-used pickers (M1 audit: web keeps these in
/// `localStorage`; on device they belong here).
class DevicePrefs {
  const DevicePrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _kThemeMode = 'finroot.theme_mode';
  static const _kTenantId = 'finroot.tenant.current';

  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  /// The workspace the user last chose. Reconciled against real memberships by
  /// [currentTenantIdProvider] — a stored id for a workspace that was left or
  /// deleted is ignored, never trusted blindly (mirrors the web
  /// `TenantContext` "stillValid" check).
  String? get tenantId => _prefs.getString(_kTenantId);

  Future<void> setTenantId(String? id) async {
    if (id == null) {
      await _prefs.remove(_kTenantId);
    } else {
      await _prefs.setString(_kTenantId, id);
    }
  }
}

/// Overridden in `bootstrap()` with the resolved instance. Reading it without
/// that override is a programming error (fails fast in every build mode).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('sharedPreferencesProvider was not overridden'),
  name: 'sharedPreferences',
);

final devicePrefsProvider = Provider<DevicePrefs>(
  (ref) => DevicePrefs(ref.watch(sharedPreferencesProvider)),
  name: 'devicePrefs',
);

/// The active [ThemeMode]. Seeded from [DevicePrefs]; [ThemeModeController.set]
/// writes through and updates the app immediately.
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
  name: 'themeMode',
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(devicePrefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    await ref.read(devicePrefsProvider).setThemeMode(mode);
    state = mode;
  }
}
