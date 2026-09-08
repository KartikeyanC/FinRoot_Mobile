import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Records that *this* running app initiated a credential exchange.
///
/// `supabase_flutter` emits `AuthChangeEvent.signedIn` on every cold-start
/// session restore, not only on a real sign-in (web BUG-090 / M1 audit §7).
/// A future app-lock must not treat a restore as a fresh authentication. The
/// screen that asks for a credential calls [mark] first; whatever consumes auth
/// events later calls [consume] and unlocks only when it returns `true`.
///
/// No lock exists yet — this is the seam so the lock, when it lands, changes
/// nothing in the auth layer.
class AuthIntent {
  bool _pending = false;

  void mark() => _pending = true;

  /// Returns the pending flag and clears it.
  bool consume() {
    final wasPending = _pending;
    _pending = false;
    return wasPending;
  }

  void clear() => _pending = false;

  bool get isPending => _pending;
}

final authIntentProvider = Provider<AuthIntent>(
  (ref) => AuthIntent(),
  name: 'authIntent',
);
