import 'package:flutter/foundation.dart';

/// Build-time configuration. Values arrive via `--dart-define-from-file`
/// (see `config/*.json`); nothing secret is committed.
///
/// The Supabase **anon/publishable** key is safe to ship in a client binary —
/// it only grants what RLS allows. A `service_role` key must NEVER appear here
/// or in any `--dart-define`.
enum AppFlavor {
  dev,
  staging,
  prod;

  static AppFlavor fromName(String v) => switch (v) {
    'prod' || 'production' => AppFlavor.prod,
    'staging' => AppFlavor.staging,
    _ => AppFlavor.dev,
  };
}

@immutable
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authDeepLinkScheme,
  });

  /// Reads the compile-time environment (`--dart-define` /
  /// `--dart-define-from-file`). Call once at startup.
  factory AppConfig.fromEnvironment() {
    return AppConfig(
      flavor: AppFlavor.fromName(
        const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
      ),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      authDeepLinkScheme: const String.fromEnvironment(
        'AUTH_DEEP_LINK_SCHEME',
        defaultValue: 'finroot',
      ),
    );
  }

  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Scheme for password-reset / (future) OAuth deep links, e.g.
  /// `finroot://auth-callback`.
  final String authDeepLinkScheme;

  bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get isProd => flavor == AppFlavor.prod;

  /// Fail fast on a misconfigured build rather than surfacing a confusing
  /// runtime error deep in the auth layer. Assertions are stripped in release,
  /// so [isConfigured] is still checked at runtime by the bootstrap.
  void assertValid() {
    assert(
      supabaseUrl.startsWith('https://'),
      'SUPABASE_URL missing or not https. Pass '
      '--dart-define-from-file=config/<flavor>.json',
    );
    assert(
      supabaseAnonKey.length > 20,
      'SUPABASE_ANON_KEY missing. Pass '
      '--dart-define-from-file=config/<flavor>.json',
    );
    assert(
      !supabaseAnonKey.contains('service_role'),
      'A service_role key must never be shipped in the client.',
    );
  }

  @override
  String toString() =>
      'AppConfig(flavor: ${flavor.name}, url: $supabaseUrl, '
      'configured: $isConfigured)';
}
