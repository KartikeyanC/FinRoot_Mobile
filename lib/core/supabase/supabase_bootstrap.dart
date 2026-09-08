import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import 'secure_local_storage.dart';

/// Initialises the shared FinRoot Supabase backend.
///
/// Same project, auth, and RLS as the web app (M1 audit §1, §8). Differences
/// from web, all native-shaped:
/// - session + PKCE verifiers live in the keystore/keychain, not localStorage;
/// - PKCE flow (deep-link friendly, required for the M3 password-reset link);
/// - no `service_role` key is present or possible here.
Future<void> initSupabase(AppConfig config) async {
  config.assertValid();
  if (!config.isConfigured) {
    // Release builds strip asserts; fail loudly rather than boot half-wired.
    throw StateError(
      'Supabase is not configured. Run with '
      '--dart-define-from-file=config/${config.flavor.name}.json',
    );
  }

  await Supabase.initialize(
    url: config.supabaseUrl,
    // The publishable (anon) key — safe in a client, RLS-gated. `anonKey` is
    // the parameter name in supabase_flutter 2.17; it is being renamed to
    // `publishableKey` upstream but the value is identical.
    // ignore: deprecated_member_use
    anonKey: config.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      // authFlowType defaults to PKCE — the deep-link-friendly flow the M3
      // password-reset link needs.
      localStorage: SecureLocalStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
    ),
    debug: !config.isProd,
  );

  AppLog.of('supabase').info('initialised (${config.flavor.name})');
}

SupabaseClient get supabase => Supabase.instance.client;
