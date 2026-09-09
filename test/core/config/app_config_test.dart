import 'dart:convert';

import 'package:finroot_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _jwt(Map<String, dynamic> payload) {
  String seg(Object o) => base64Url
      .encode(utf8.encode(jsonEncode(o)))
      .replaceAll('=', '');
  return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(payload)}.sig';
}

AppConfig _cfg(String key) => AppConfig(
  flavor: AppFlavor.dev,
  supabaseUrl: 'https://example.supabase.co',
  supabaseAnonKey: key,
  authDeepLinkScheme: 'finroot',
);

void main() {
  test('defaults to dev flavor and unconfigured when no dart-defines', () {
    // Tests run with no --dart-define unless the runner passes them.
    final config = AppConfig.fromEnvironment();
    expect(config.flavor, AppFlavor.dev);
    expect(config.authDeepLinkScheme, 'finroot');
    // In CI without a config file this is false; that is the expected default.
    expect(config.isConfigured, config.supabaseUrl.isNotEmpty);
  });

  test('flavor name mapping', () {
    expect(AppFlavor.fromName('prod'), AppFlavor.prod);
    expect(AppFlavor.fromName('production'), AppFlavor.prod);
    expect(AppFlavor.fromName('staging'), AppFlavor.staging);
    expect(AppFlavor.fromName('anything-else'), AppFlavor.dev);
  });

  test('assertValid rejects a missing url', () {
    const bad = AppConfig(
      flavor: AppFlavor.dev,
      supabaseUrl: '',
      supabaseAnonKey: '',
      authDeepLinkScheme: 'finroot',
    );
    expect(bad.assertValid, throwsA(isA<AssertionError>()));
  });

  group('assertValid — privileged key guard (M18 F-4)', () {
    test('rejects a legacy service_role JWT (claim is base64-encoded)', () {
      final cfg = _cfg(_jwt({'role': 'service_role', 'iss': 'supabase'}));
      // A plain `.contains("service_role")` would have missed this.
      expect(cfg.supabaseAnonKey.contains('service_role'), isFalse);
      expect(cfg.assertValid, throwsA(isA<AssertionError>()));
    });

    test('rejects a new-format sb_secret_ key', () {
      expect(_cfg('sb_secret_abcdefghijklmnopqrstuvwxyz').assertValid,
          throwsA(isA<AssertionError>()));
    });

    test('accepts a legacy anon JWT', () {
      expect(_cfg(_jwt({'role': 'anon', 'iss': 'supabase'})).assertValid,
          returnsNormally);
    });

    test('accepts a new-format sb_publishable_ key', () {
      expect(
        _cfg('sb_publishable_abcdefghijklmnopqrstuvwxyz').assertValid,
        returnsNormally,
      );
    });
  });
}
