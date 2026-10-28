import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../data/auth_intent.dart';
import '../data/auth_repository.dart';

/// State of the auth form's current action. Navigation on success is the
/// router's job (it reacts to the session appearing) — this only carries what
/// the form itself must show: busy, error, or a "check your email" outcome.
sealed class AuthActionState {
  const AuthActionState();
}

class AuthIdle extends AuthActionState {
  const AuthIdle();
}

class AuthBusy extends AuthActionState {
  const AuthBusy();
}

class AuthFailed extends AuthActionState {
  const AuthFailed(this.failure);
  final Failure failure;
}

/// Sign-up succeeded but the account needs email confirmation before sign-in.
class AuthAwaitingConfirmation extends AuthActionState {
  const AuthAwaitingConfirmation(this.email);
  final String email;
}

/// A password-reset email was sent.
class AuthResetEmailSent extends AuthActionState {
  const AuthResetEmailSent(this.email);
  final String email;
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthActionState>(
      AuthController.new,
      name: 'authController',
    );

class AuthController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthIdle();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  AuthIntent get _intent => ref.read(authIntentProvider);

  void reset() => state = const AuthIdle();

  Future<void> signIn({required String email, required String password}) async {
    await _run(() async {
      _intent.mark();
      try {
        await _repo.signIn(email: email, password: password);
      } catch (_) {
        _intent.clear();
        rethrow;
      }
    });
  }

  /// Opens Google in the browser. The session arrives later through the
  /// deep link, so the form is idle again as soon as the browser is open;
  /// the router takes over when the session appears.
  Future<void> signInWithGoogle() async {
    await _run(() async {
      _intent.mark();
      try {
        final launched = await _repo.signInWithGoogle();
        if (!launched) {
          throw const AuthFailure(
            'Could not open a browser for Google sign-in.',
          );
        }
      } catch (_) {
        _intent.clear();
        rethrow;
      }
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AuthBusy();
    try {
      _intent.mark();
      final outcome = await _repo.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (outcome.needsEmailConfirmation) {
        _intent.clear();
        state = AuthAwaitingConfirmation(email.trim());
      } else {
        // Signed in immediately — router takes over; keep a clean idle state.
        state = const AuthIdle();
      }
    } catch (error, stack) {
      _intent.clear();
      state = AuthFailed(mapError(error, stack));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    state = const AuthBusy();
    try {
      await _repo.sendPasswordReset(email);
      state = AuthResetEmailSent(email.trim());
    } catch (error, stack) {
      state = AuthFailed(mapError(error, stack));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AuthBusy();
    try {
      await action();
      state = const AuthIdle();
    } catch (error, stack) {
      state = AuthFailed(mapError(error, stack));
    }
  }
}
