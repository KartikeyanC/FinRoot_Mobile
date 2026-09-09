import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/local/database_providers.dart';
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
    await _ref.read(authRepositoryProvider).signOut();
    await wipeLocalData(_ref);
    log.info('signed out and wiped local data');
  }
}
