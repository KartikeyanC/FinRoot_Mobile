import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device/device_prefs.dart';
import '../design/theme/app_theme.dart';
import '../features/notifications/application/notification_coordinator.dart';
import '../features/sync/application/sync_coordinator.dart';
import 'display_scale.dart';
import 'router.dart';

/// Root widget. The theme is a mode ([themeModeProvider], light by default)
/// times a colour theme ([colorThemeProvider], FinRoot by default), both
/// chosen in Settings → Appearance, as is the display size
/// ([displaySizeProvider], 100 % by default).
class FinRootApp extends ConsumerWidget {
  const FinRootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorTheme = ref.watch(colorThemeProvider);
    final displaySize = ref.watch(displaySizeProvider);
    return MaterialApp.router(
      title: 'FinRoot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, colorTheme),
      darkTheme: AppTheme.build(Brightness.dark, colorTheme),
      themeMode: themeMode,
      routerConfig: router,
      // Keeps the sync + notification coordinators alive for the app's lifetime,
      // and draws everything, overlays included, at the chosen display size.
      builder: (context, child) => DisplayScale(
        scale: displaySize / 100,
        child: SyncScope(
          child: NotificationScope(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
