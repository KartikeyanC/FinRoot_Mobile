import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/device/device_prefs.dart';
import 'core/error/error_mapper.dart';
import 'core/logging/app_logger.dart';
import 'core/logging/provider_logger.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/sync/application/background_sync.dart';

/// Single async entrypoint used by `main.dart` (and, later, per-flavor mains).
///
/// Order matters: logging → config → Supabase → runApp, all inside a guarded
/// zone so an uncaught error is logged (redacted) rather than lost.
Future<void> bootstrap() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      AppLog.init();

      final log = AppLog.of('bootstrap');
      final config = AppConfig.fromEnvironment();
      log.info('starting — $config');

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        AppLog.of('flutter').severe(
          'widget error',
          mapError(details.exception, details.stack),
          details.stack,
        );
      };

      await initSupabase(config);
      final prefs = await SharedPreferences.getInstance();

      // Fire-and-forget: registers the OS periodic background sync. Never
      // blocks or fails startup (device config pending — M5 report).
      unawaited(initBackgroundSync());

      runApp(
        ProviderScope(
          observers: const [ProviderLogger()],
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const FinRootApp(),
        ),
      );
    },
    (error, stack) {
      // Last-resort handler. The Failure mapping keeps sensitive detail out of
      // the log line; the raw error still goes to `error:` for the console.
      AppLog.of('zone').severe('uncaught', mapError(error, stack), stack);
    },
  );
}
