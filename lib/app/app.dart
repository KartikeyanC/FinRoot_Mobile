import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device/device_prefs.dart';
import '../design/theme/app_theme.dart';
import 'router.dart';

/// Root widget. Light/dark themes are defined once; the active mode comes from
/// [themeModeProvider] (Settings → Appearance), defaulting to the system.
class FinRootApp extends ConsumerWidget {
  const FinRootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FinRoot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
