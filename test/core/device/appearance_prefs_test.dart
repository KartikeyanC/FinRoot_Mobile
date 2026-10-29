import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<DevicePrefs> _prefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return DevicePrefs(await SharedPreferences.getInstance());
}

void main() {
  test('nothing stored: light mode, FinRoot colour theme', () async {
    final p = await _prefs({});
    expect(p.themeMode, ThemeMode.light);
    expect(p.colorTheme, AppColorTheme.finroot);
  });

  test('an old theme_mode choice migrates to FinRoot + that mode', () async {
    for (final (stored, mode) in [
      ('dark', ThemeMode.dark),
      ('light', ThemeMode.light),
      ('system', ThemeMode.system),
    ]) {
      final p = await _prefs({'finroot.theme_mode': stored});
      expect(p.themeMode, mode);
      expect(p.colorTheme, AppColorTheme.finroot);
    }
  });

  test(
    'colour theme round-trips; unknown names fall back to FinRoot',
    () async {
      final p = await _prefs({'finroot.color_theme': 'nope'});
      expect(p.colorTheme, AppColorTheme.finroot);
      await p.setColorTheme(AppColorTheme.berry);
      expect(p.colorTheme, AppColorTheme.berry);
    },
  );

  test('every colour theme builds in both modes with its palette', () {
    for (final t in AppColorTheme.values) {
      for (final b in Brightness.values) {
        final theme = AppTheme.build(b, t);
        expect(theme.brightness, b);
        expect(theme.extension<AppPalette>(), t.palette(b));
        expect(theme.scaffoldBackgroundColor, t.palette(b).page);
      }
    }
  });
}
