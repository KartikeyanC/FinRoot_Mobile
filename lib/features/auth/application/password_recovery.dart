import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';

/// True once the user has opened a password-reset deep link
/// (`finroot://auth-callback` → `AuthChangeEvent.passwordRecovery`). While set,
/// the router forces the reset-password screen; that screen calls [clear] when
/// the password is changed or the user backs out.
///
/// `supabase_flutter` handles the incoming link and creates a short-lived
/// session; it does not navigate. This is the bridge to the router.
final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryController, bool>(
      PasswordRecoveryController.new,
      name: 'passwordRecovery',
    );

class PasswordRecoveryController extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authEventProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        AppLog.of('auth').info('password recovery link opened');
        state = true;
      }
    });
    return false;
  }

  void clear() => state = false;
}
