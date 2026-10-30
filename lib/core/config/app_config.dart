import 'dart:convert';

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

/// Where the FinRoot web app lives. UNCONFIRMED default: the only domain found
/// in the repo is `finroot.app` (used for e-mail addresses). Override with
/// `--dart-define WEB_APP_URL=...` (see config/*.json).
const defaultWebAppUrl = 'https://finroot.app';

@immutable
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.authDeepLinkScheme,
    this.webAppUrl = defaultWebAppUrl,
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
      // ignore: avoid_redundant_argument_values
      webAppUrl: const String.fromEnvironment(
        'WEB_APP_URL',
        defaultValue: defaultWebAppUrl,
      ),
    );
  }

  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Scheme for password-reset / (future) OAuth deep links, e.g.
  /// `finroot://auth-callback`.
  final String authDeepLinkScheme;

  /// Base URL of the web app (no trailing slash needed). Web-only menus
  /// (Trips, Import, Billing, member management) open `<webAppUrl>/app/<page>`.
  final String webAppUrl;

  /// The web app page at [path] (e.g. `trips`), under `/app/`.
  Uri webAppPage(String path) {
    final base = webAppUrl.endsWith('/')
        ? webAppUrl.substring(0, webAppUrl.length - 1)
        : webAppUrl;
    return Uri.parse('$base/app/$path');
  }

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
      !_isPrivilegedKey(supabaseAnonKey),
      'A service_role / secret key must never be shipped in the client. '
      'Use the anon / publishable key.',
    );
  }

  /// True if [key] is a Supabase **service_role / secret** key rather than the
  /// publishable (anon) one. Handles both key formats:
  /// - new: `sb_secret_…` (vs `sb_publishable_…`);
  /// - legacy JWT: a `"role":"service_role"` claim in the (base64url) payload.
  ///   A plain `.contains('service_role')` never matches — the claim is encoded.
  static bool _isPrivilegedKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parts = key.split('.');
    if (parts.length != 3) return false; // not a JWT — can't tell, don't block
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final role = (jsonDecode(payload) as Map<String, dynamic>)['role'];
      return role == 'service_role';
    } catch (_) {
      return false;
    }
  }

  @override
  String toString() =>
      'AppConfig(flavor: ${flavor.name}, url: $supabaseUrl, '
      'configured: $isConfigured)';
}
