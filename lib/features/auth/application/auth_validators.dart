/// Pure form validators, returning a user-facing message or `null` when valid.
/// Kept out of widgets so they can be tested directly and reused by sign-in,
/// sign-up and reset. Rules mirror the web app (`Auth.tsx` zod schema):
/// password 8–72 chars; email a basic shape check (the server is authoritative).
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const int passwordMin = 8;
  static const int passwordMax = 72;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length < 2) return 'That name looks too short';
    if (v.length > 80) return 'That name is too long';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Enter a password';
    if (v.length < passwordMin) {
      return 'Use at least $passwordMin characters';
    }
    if (v.length > passwordMax) {
      return 'Keep it under $passwordMax characters';
    }
    return null;
  }

  /// Sign-in is lenient — any non-empty password. The server rejects a wrong
  /// one; a length rule here would only nag a returning user.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Re-enter the password';
    if (value != original) return 'The passwords do not match';
    return null;
  }
}
