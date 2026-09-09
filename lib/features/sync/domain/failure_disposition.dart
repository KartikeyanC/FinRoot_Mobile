import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';

/// What to do with an outbox entry whose send failed.
enum FailureDisposition {
  /// Transient (offline, timeout, expired token) — leave the entry pending,
  /// stop this run, try again later.
  retry,

  /// `apply_transaction_mutation` is not deployed yet (M1.5 not applied). Hold
  /// the whole queue without counting attempts — it is not the entry's fault.
  holdBackendMissing,

  /// Permanent (permission, validation, a reused id) — park the entry as
  /// `failed` and flag its cache row. Needs the user.
  permanent,

  /// The target row is already gone on the server (`P0002` on update/delete).
  /// The intended outcome is effectively achieved — drop the local row and
  /// clear the entry.
  reconcileGone,
}

/// Classify a mapped [Failure] (plus its original cause) into a disposition.
/// The retry/permanent split follows `backend/M1.5_CLIENT_CONTRACT.md` §5.
FailureDisposition classifyMutationFailure(Failure failure) {
  final cause = failure.cause;
  if (cause is PostgrestException) {
    final code = cause.code ?? '';
    if (code == 'P0002') return FailureDisposition.reconcileGone;
    // PGRST202 = function not found in the schema cache.
    if (code == 'PGRST202') return FailureDisposition.holdBackendMissing;
  }
  return switch (failure) {
    NetworkFailure() => FailureDisposition.retry,
    AuthFailure() => FailureDisposition.retry, // a token refresh may fix it
    PermissionFailure() => FailureDisposition.permanent,
    ValidationFailure() => FailureDisposition.permanent,
    ConflictFailure() => FailureDisposition.permanent,
    UnexpectedFailure() =>
      failure.isRetryable
          ? FailureDisposition.retry
          : FailureDisposition.permanent,
  };
}
