import 'package:finroot_mobile/features/auth/application/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('rejects empty and malformed', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('  '), isNotNull);
      expect(AuthValidators.email('not-an-email'), isNotNull);
      expect(AuthValidators.email('a@b'), isNotNull);
    });

    test('accepts a normal address, trimmed', () {
      expect(AuthValidators.email('aji.rio.96@gmail.com'), isNull);
      expect(AuthValidators.email('  user@finroot.app  '), isNull);
    });
  });

  group('password (sign-up)', () {
    test('enforces the 8..72 range from the web zod schema', () {
      expect(AuthValidators.password(''), isNotNull);
      expect(AuthValidators.password('short'), isNotNull);
      expect(AuthValidators.password('a' * 7), isNotNull);
      expect(AuthValidators.password('a' * 8), isNull);
      expect(AuthValidators.password('a' * 72), isNull);
      expect(AuthValidators.password('a' * 73), isNotNull);
    });
  });

  group('loginPassword (sign-in)', () {
    test('only requires non-empty — no length nag for returning users', () {
      expect(AuthValidators.loginPassword(''), isNotNull);
      expect(AuthValidators.loginPassword('x'), isNull);
    });
  });

  group('confirmPassword', () {
    test('must match the original', () {
      expect(AuthValidators.confirmPassword('abcd1234', 'abcd1234'), isNull);
      expect(
        AuthValidators.confirmPassword('abcd1234', 'different'),
        isNotNull,
      );
      expect(AuthValidators.confirmPassword('', 'abcd1234'), isNotNull);
    });
  });

  group('name', () {
    test('bounds', () {
      expect(AuthValidators.name(''), isNotNull);
      expect(AuthValidators.name('A'), isNotNull);
      expect(AuthValidators.name('Aji'), isNull);
      expect(AuthValidators.name('a' * 81), isNotNull);
    });
  });
}
