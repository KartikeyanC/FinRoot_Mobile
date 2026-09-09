import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../supabase/supabase_bootstrap.dart';

/// Resolved compile-time configuration.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
  name: 'appConfig',
);

/// The shared Supabase client. Assumes [initSupabase] ran in the bootstrap.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => supabase,
  name: 'supabaseClient',
);

/// Auth events (`SIGNED_IN`, `SIGNED_OUT`, `TOKEN_REFRESHED`, …).
///
/// ⚠️ `SIGNED_IN` does NOT mean a person just signed in — gotrue also emits it
/// on every session restore (web CLAUDE.md / BUG-090). M3 adds the
/// "sign-in intent" guard before this drives any app-lock behaviour.
final authEventProvider = StreamProvider<AuthState>(
  (ref) => ref.watch(supabaseClientProvider).auth.onAuthStateChange,
  name: 'authEvent',
);

/// The current session, kept in sync with [authEventProvider]. Null = signed
/// out. This is what the router's redirect reads.
final sessionProvider = Provider<Session?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  // Re-read on every auth event.
  ref.watch(authEventProvider);
  return client.auth.currentSession;
}, name: 'session');

final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(sessionProvider)?.user,
  name: 'currentUser',
);

/// The signed-in user's id, or null. A small seam so writers (M7 Quick Add)
/// can depend on the id without pulling in the whole [User] — and can be
/// overridden directly in tests.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider)?.id,
  name: 'currentUserId',
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(sessionProvider) != null,
  name: 'isSignedIn',
);

/// Coarse online/offline signal for the M5 sync engine and offline banners.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
  name: 'connectivity',
);

final isOnlineProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityProvider).value;
  if (results == null) return true; // optimistic until first reading
  return results.any((ConnectivityResult r) => r != ConnectivityResult.none);
}, name: 'isOnline');
