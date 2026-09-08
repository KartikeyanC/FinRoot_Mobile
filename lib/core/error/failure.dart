/// A user-facing failure. Repositories and services throw or return these
/// instead of raw `PostgrestException` / `AuthException` / `SocketException`,
/// so the UI never has to interpret a backend error and error copy lives in
/// one place (brief §49: "RPC_ERROR_23505" is never shown).
sealed class Failure implements Exception {
  const Failure(this.message, {this.cause, this.isRetryable = false});

  /// Short, plain-language, safe to show. Never contains an amount, account id,
  /// description, token, or raw server text.
  final String message;

  /// The original error, for logging only — never rendered.
  final Object? cause;

  final bool isRetryable;

  @override
  String toString() => '$runtimeType: $message';
}

/// No connectivity, timeout, DNS — the operation can be retried as-is.
class NetworkFailure extends Failure {
  const NetworkFailure({super.cause})
    : super(
        "You're offline. We'll finish this when the connection is back.",
        isRetryable: true,
      );
}

/// Session missing or expired.
class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});

  factory AuthFailure.sessionExpired() =>
      const AuthFailure('Your session ended. Please sign in again.');
}

/// RLS denied the row, or the caller lacks the role / plan menu.
class PermissionFailure extends Failure {
  const PermissionFailure({String? message, super.cause})
    : super(message ?? "You don't have access to do that in this workspace.");
}

/// The server rejected the input (constraint violation, bad shape).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause});
}

/// A write conflicted with a newer server version (M5 sync).
class ConflictFailure extends Failure {
  const ConflictFailure({String? message, super.cause})
    : super(
        message ?? 'This was changed somewhere else. Review and try again.',
      );
}

/// Anything not otherwise classified.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({super.cause})
    : super(
        'Something went wrong. Your data is safe — please try again.',
        isRetryable: true,
      );
}
