import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import 'app_database.dart';
import 'database_key.dart';
import 'encrypted_connection.dart';

/// The single [AppDatabase] instance. Opened lazily (first query), closed when
/// the provider is disposed.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.encrypted();
  ref.onDispose(db.close);
  return db;
}, name: 'appDatabase');

final syncOutboxDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).syncOutboxDao,
  name: 'syncOutboxDao',
);

final syncStateDaoProvider = Provider(
  (ref) => ref.watch(appDatabaseProvider).syncStateDao,
  name: 'syncStateDao',
);

/// Wipe every trace of the local cache — the database file and its key.
/// Called on a confirmed sign-out (wired into the sign-out flow in M5, so the
/// outbox and sync engine can flush or abandon cleanly first).
Future<void> wipeLocalData(Ref ref) async {
  try {
    await ref.read(appDatabaseProvider).close();
  } on Object catch (e) {
    AppLog.of('db').warning('close during wipe failed: ${e.runtimeType}');
  }
  await deleteDatabaseFile();
  await ref.read(databaseKeyProvider).delete();
  ref.invalidate(appDatabaseProvider);
}
