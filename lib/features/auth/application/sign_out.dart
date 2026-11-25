import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/local/database_providers.dart';
import '../../home_screen_widget/application/home_widget_providers.dart';
import '../../sync/application/sync_engine.dart';
import '../data/auth_repository.dart';

final signOutControllerProvider = Provider<SignOutController>(
  (ref) => SignOutController(ref),
  name: 'signOutController',
);

/// The sign-out sequence: flush what we can, end the session, wipe the cache.
///
/// Order matters — flush first (while we still have a session and a workspace),
/// then sign out, then wipe the encrypted database and its key so nothing of
/// the previous user survives on the device (brief §51).
class SignOutController {
  SignOutController(this._ref);
  final Ref _ref;

  Future<void> signOut() async {
    final log = AppLog.of('auth');
    try {
      await _ref.read(syncEngineProvider.notifier).flushBeforeSignOut();
    } on Object catch (e) {
      log.warning('flush before sign-out skipped: ${e.runtimeType}');
    }
    // `AuthRepository.signOut` never throws — it clears the session and purges
    // the keystore even offline. The local cache wipe then always runs, so a
    // failed server revoke never leaves a readable database behind.
    await _ref.read(authRepositoryProvider).signOut();
    try {
      await wipeLocalData(_ref);
    } on Object catch (e) {
      log.severe('local data wipe failed: ${e.runtimeType}');
      rethrow;
    }
    // The home-screen widget must not keep showing this person's spend.
    try {
      await _ref.read(homeWidgetGatewayProvider).clear();
    } on Object catch (e) {
      log.warning('home-screen widget not cleared: ${e.runtimeType}');
    }
    log.info('signed out and wiped local data');
  }
}
