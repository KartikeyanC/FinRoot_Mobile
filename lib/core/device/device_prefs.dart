import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/tokens/app_palette.dart';

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
  static const _kColorTheme = 'finroot.color_theme';
  static const _kTenantId = 'finroot.tenant.current';
  static const _kDisplaySize = 'finroot.display_size';

  /// Appearance follows NineFlow's model: a [ThemeMode] plus an
  /// [AppColorTheme], stored separately.
  ///
  /// Migration from the single "theme_mode" setting: its stored value
  /// ('light' / 'dark' / 'system') keeps meaning the mode, and a device with
  /// no colour theme stored gets FinRoot — so an old choice becomes
  /// FinRoot + that mode with nothing rewritten. Nothing stored → light, the
  /// NineFlow default.
  ThemeMode get themeMode => switch (_prefs.getString(_kThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_kThemeMode, mode.name);

  AppColorTheme get colorTheme =>
      AppColorTheme.fromName(_prefs.getString(_kColorTheme));

  Future<void> setColorTheme(AppColorTheme theme) =>
      _prefs.setString(_kColorTheme, theme.name);

  /// How large the whole app is drawn, in percent ([DisplaySize]). Per device
  /// on purpose: a small phone and a tablet want different answers.
  int get displaySize {
    final stored = _prefs.getInt(_kDisplaySize);
    return stored == null ? DisplaySize.standard : DisplaySize.clamp(stored);
  }

  /// The default is stored as nothing, so a later change to the default
  /// reaches everyone who never moved the setting.
  Future<void> setDisplaySize(int percent) async {
    final size = DisplaySize.clamp(percent);
    if (size == DisplaySize.standard) {
      await _prefs.remove(_kDisplaySize);
    } else {
      await _prefs.setInt(_kDisplaySize, size);
    }
  }

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

/// Settings → Appearance → Display size: the scale the whole app is drawn at,
/// in percent. The same range and steps as the web app's Display size.
abstract final class DisplaySize {
  static const int min = 75;
  static const int max = 125;
  static const int step = 5;
  static const int standard = 100;

  /// Any value onto the scale: a whole step, between [min] and [max].
  static int clamp(num value) {
    if (!value.isFinite) return standard;
    final stepped = (value / step).round() * step;
    return stepped.clamp(min, max).toInt();
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

/// The active [AppColorTheme] (FinRoot, Ocean, Forest, Berry, Graphite).
/// Seeded from [DevicePrefs]; [ColorThemeController.set] writes through.
final colorThemeProvider =
    NotifierProvider<ColorThemeController, AppColorTheme>(
      ColorThemeController.new,
      name: 'colorTheme',
    );

class ColorThemeController extends Notifier<AppColorTheme> {
  @override
  AppColorTheme build() => ref.watch(devicePrefsProvider).colorTheme;

  Future<void> set(AppColorTheme theme) async {
    await ref.read(devicePrefsProvider).setColorTheme(theme);
    state = theme;
  }
}

/// The active display size in percent ([DisplaySize]). Seeded from
/// [DevicePrefs]; [DisplaySizeController.set] applies it at once, then saves.
final displaySizeProvider = NotifierProvider<DisplaySizeController, int>(
  DisplaySizeController.new,
  name: 'displaySize',
);

class DisplaySizeController extends Notifier<int> {
  @override
  int build() => ref.watch(devicePrefsProvider).displaySize;

  Future<void> set(int percent) async {
    final size = DisplaySize.clamp(percent);
    // State first: the slider lets go and the app resizes in the same frame,
    // instead of springing back while the write finishes.
    state = size;
    await ref.read(devicePrefsProvider).setDisplaySize(size);
  }
}
