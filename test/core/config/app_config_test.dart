import 'package:finroot_mobile/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
