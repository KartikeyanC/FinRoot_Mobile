import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/error_mapper.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../core/supabase/secure_local_storage.dart';

/// Outcome of a sign-up. When the project has email confirmation on, `signUp`
/// returns no session and the UI must tell the user to check their mail.
class SignUpOutcome {
  const SignUpOutcome({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

/// The only place the app talks to gotrue.
///
/// Same auth architecture as the web app (M1 audit §7) — email + password,
/// `handle_new_user()` creates the profile + personal workspace + owner
/// membership + Free subscription server-side. No Google/OAuth in V1
/// (decision 4). Every method maps backend errors to a [Failure] so no screen
/// ever sees a raw `AuthException`.
class AuthRepository {
  AuthRepository(this._client, this._config);

  final SupabaseClient _client;
  final AppConfig _config;

  GoTrueClient get _auth => _client.auth;
  final _log = AppLog.of('auth');

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  /// `finroot://auth-callback` — used for the password-reset link. The Supabase
  /// project's Auth "Redirect URLs" allow-list must include this exact value
  /// (a dashboard setting, additive, no web impact — see M3 report).
  String get _redirect => '${_config.authDeepLinkScheme}://auth-callback';

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      _log.info('signIn ok for ${redact(email)}');
    } catch (error, stack) {
      _log.warning('signIn failed for ${redact(email)}');
      throw mapError(error, stack);
    }
  }

  Future<SignUpOutcome> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        // `handle_new_user()` reads display_name / full_name for the workspace
        // name ("<name>'s Workspace").
        data: {'display_name': name.trim(), 'full_name': name.trim()},
        emailRedirectTo: _redirect,
      );
      _log.info(
        'signUp ok for ${redact(email)} (session: ${res.session != null})',
      );
      return SignUpOutcome(needsEmailConfirmation: res.session == null);
    } catch (error, stack) {
      _log.warning('signUp failed for ${redact(email)}');
      throw mapError(error, stack);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim().toLowerCase(),
        redirectTo: _redirect,
      );
      _log.info('password reset requested for ${redact(email)}');
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  /// Set a new password. Valid only inside an active session — either normally,
  /// or the temporary session created by opening the recovery deep link.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      _log.info('password updated');
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  /// Sign out and wipe every FinRoot secret from the keystore (brief §51).
  ///
  /// Leaving must always succeed. gotrue clears the local session and emits
  /// `signedOut` **before** it calls the server, so an offline failure of the
  /// server revoke is harmless — the session is already gone locally. We
  /// swallow it, always purge the keystore, and never throw; the caller then
  /// wipes the local cache unconditionally.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error) {
      _log.warning(
        'signOut server revoke failed (${error.runtimeType}); '
        'local session already cleared',
      );
    } finally {
      await purgeSecureStorage();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(appConfigProvider),
  ),
  name: 'authRepository',
);
