import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/features/sync/domain/failure_disposition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('network / auth → retry', () {
    expect(
      classifyMutationFailure(const NetworkFailure()),
      FailureDisposition.retry,
    );
    expect(
      classifyMutationFailure(AuthFailure.sessionExpired()),
      FailureDisposition.retry,
    );
  });

  test('permission / validation / conflict → permanent', () {
    expect(
      classifyMutationFailure(const PermissionFailure()),
      FailureDisposition.permanent,
    );
    expect(
      classifyMutationFailure(const ValidationFailure('bad')),
      FailureDisposition.permanent,
    );
    expect(
      classifyMutationFailure(const ConflictFailure()),
      FailureDisposition.permanent,
    );
  });

  test('P0002 (row already gone) → reconcileGone', () {
    const f = UnexpectedFailure(
      cause: PostgrestException(message: 'no such transaction', code: 'P0002'),
    );
    expect(classifyMutationFailure(f), FailureDisposition.reconcileGone);
  });

  test('PGRST202 (RPC not deployed) → holdBackendMissing', () {
    const f = UnexpectedFailure(
      cause: PostgrestException(
        message: 'Could not find the function',
        code: 'PGRST202',
      ),
    );
    expect(classifyMutationFailure(f), FailureDisposition.holdBackendMissing);
  });
}
