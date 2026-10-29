import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/device/device_prefs.dart';
import '../design/theme/app_theme.dart';
import '../features/notifications/application/notification_coordinator.dart';
import '../features/sync/application/sync_coordinator.dart';
import 'router.dart';

/// Root widget. The theme is a mode ([themeModeProvider], light by default)
/// times a colour theme ([colorThemeProvider], FinRoot by default), both
/// chosen in Settings → Appearance.
class FinRootApp extends ConsumerWidget {
  const FinRootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colorTheme = ref.watch(colorThemeProvider);
    return MaterialApp.router(
      title: 'FinRoot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(Brightness.light, colorTheme),
      darkTheme: AppTheme.build(Brightness.dark, colorTheme),
      themeMode: themeMode,
      routerConfig: router,
      // Keeps the sync + notification coordinators alive for the app's lifetime.
      builder: (context, child) => SyncScope(
        child: NotificationScope(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
