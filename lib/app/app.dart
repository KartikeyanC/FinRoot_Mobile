import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/theme/app_theme.dart';
import 'router.dart';

/// Root widget. Theme is system-driven for now (light/dark); an explicit
/// override lands with Settings in M3.
class FinRootApp extends ConsumerWidget {
  const FinRootApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FinRoot',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // themeMode defaults to system; an explicit override lands with Settings (M3).
      routerConfig: router,
    );
  }
}
