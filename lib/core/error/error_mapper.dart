import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failure.dart';

/// Turns any thrown object into a [Failure]. The one place backend error codes
/// are interpreted. Keep it exhaustive-ish and boring.
Failure mapError(Object error, [StackTrace? stack]) {
  if (error is Failure) return error;

  if (error is SocketException || error is TimeoutException) {
    return NetworkFailure(cause: error);
  }

  if (error is AuthException) {
    return AuthFailure(
      _looksExpired(error.message)
          ? 'Your session ended. Please sign in again.'
          : 'Sign-in failed. Check your email and password.',
      cause: error,
    );
  }

  if (error is PostgrestException) {
    final code = error.code ?? '';
    // 42501 = insufficient_privilege (RLS). PGRST301 = JWT expired.
    if (code == '42501') return PermissionFailure(cause: error);
    if (code == 'PGRST301') return AuthFailure.sessionExpired();
    // 23505 unique_violation, 23514 check_violation, 23503 fk_violation.
    if (code.startsWith('23')) {
      return ValidationFailure(
        "That didn't pass a check. Review the details and try again.",
        cause: error,
      );
    }
    return UnexpectedFailure(cause: error);
  }

  if (error is StorageException) {
    return UnexpectedFailure(cause: error);
  }

  return UnexpectedFailure(cause: error);
}

bool _looksExpired(String message) {
  final m = message.toLowerCase();
  return m.contains('expired') || m.contains('invalid refresh token');
}
