import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../../core/device/device_prefs.dart';
import '../../core/error/failure.dart';
import '../../core/logging/app_logger.dart';
import '../../core/providers/providers.dart';
import '../workspace/application/workspace_providers.dart';
import 'backup_data.dart';
import 'drive_client.dart';

/// Gets a Google Drive access token. [interactive] may show Google's account
/// picker / consent; otherwise it only succeeds if access was granted before.
abstract interface class DriveAuth {
  Future<String?> token({required bool interactive});
  Future<void> disconnect();
}

/// Google sign-in for Drive only (scope `drive.file`: the app sees just the
/// files it creates). Needs an Android OAuth client for `com.finroot.mobile`
/// + the APK's SHA-1 in the person's Google Cloud project — see
/// docs/GOOGLE_DRIVE_BACKUP.md.
class GoogleDriveAuth implements DriveAuth {
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize();
    _ready = true;
  }

  @override
  Future<String?> token({required bool interactive}) async {
    try {
      await _init();
      final client = GoogleSignIn.instance.authorizationClient;
      final auth = interactive
          ? await client.authorizeScopes(const [driveFileScope])
          : await client.authorizationForScopes(const [driveFileScope]);
      return auth?.accessToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ValidationFailure(
        'Google sign-in failed (${e.code.name}). If this keeps happening, the '
        'Google Cloud setup for Drive backup is not finished yet.',
      );
    } on PlatformException catch (e) {
      throw ValidationFailure('Google sign-in failed: ${e.message ?? e.code}');
    }
  }

  @override
  Future<void> disconnect() async {
    await _init();
    await GoogleSignIn.instance.disconnect();
  }
}

final driveAuthProvider = Provider<DriveAuth>((ref) => GoogleDriveAuth(), name: 'driveAuth');

final driveClientFactoryProvider = Provider<DriveClient Function(String token)>(
  (ref) => DriveClient.new,
  name: 'driveClientFactory',
);

final backupDataSourceProvider = Provider<BackupDataSource>(
  (ref) => BackupDataSource(ref.watch(supabaseClientProvider)),
  name: 'backupDataSource',
);

/// How many backups to keep in Drive; older ones are deleted.
const keepBackups = 30;

const _lastKey = 'drive_backup.last_at';
const _autoKey = 'drive_backup.auto';

String backupFileName(String workspace, DateTime at) {
  final safe = workspace.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return 'FinRoot-${safe.isEmpty ? 'workspace' : safe}-${DateFormat('yyyy-MM-dd-HHmm').format(at)}.json';
}

/// True when an automatic backup is due: on, and none in the last 24 h.
bool autoBackupDue({required bool enabled, DateTime? last, required DateTime now}) =>
    enabled && (last == null || now.difference(last) >= const Duration(hours: 24));

class DriveBackupState {
  const DriveBackupState({this.lastBackupAt, this.autoEnabled = false, this.busy = false});
  final DateTime? lastBackupAt;
  final bool autoEnabled;
  final bool busy;

  DriveBackupState copyWith({DateTime? lastBackupAt, bool? autoEnabled, bool? busy}) => DriveBackupState(
        lastBackupAt: lastBackupAt ?? this.lastBackupAt,
        autoEnabled: autoEnabled ?? this.autoEnabled,
        busy: busy ?? this.busy,
      );
}

/// Google Drive backup next to the Supabase sync: Supabase stays the live
/// copy that web and phone share; Drive holds dated snapshot files the person
/// owns. Restore only adds back rows that are missing, so it never fights the
/// sync or overwrites newer edits.
class DriveBackupController extends Notifier<DriveBackupState> {
  final _log = AppLog.of('backup');

  @override
  DriveBackupState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final last = prefs.getString(_lastKey);
    return DriveBackupState(
      lastBackupAt: last == null ? null : DateTime.tryParse(last),
      autoEnabled: prefs.getBool(_autoKey) ?? false,
    );
  }

  Future<void> setAuto(bool on) async {
    await ref.read(sharedPreferencesProvider).setBool(_autoKey, on);
    state = state.copyWith(autoEnabled: on);
  }

  Future<DriveClient> _drive({required bool interactive}) async {
    final token = await ref.read(driveAuthProvider).token(interactive: interactive);
    if (token == null) {
      throw const ValidationFailure('Choose a Google account to use Drive backup.');
    }
    return ref.read(driveClientFactoryProvider)(token);
  }

  String _tenant() {
    final id = ref.read(currentTenantIdProvider);
    if (id == null) throw AuthFailure.sessionExpired();
    return id;
  }

  Future<T> _run<T>(Future<T> Function() body) async {
    if (!ref.read(isOnlineProvider)) {
      throw const ValidationFailure('Connect to the internet to use Drive backup.');
    }
    state = state.copyWith(busy: true);
    try {
      return await body();
    } on DriveException catch (e) {
      throw ValidationFailure(e.message);
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// Exports the workspace from Supabase and uploads it to Drive. Returns the
  /// backup that was saved.
  Future<WorkspaceBackup> backUpNow({bool interactive = true}) => _run(() async {
        final tenantId = _tenant();
        final drive = await _drive(interactive: interactive);
        final name = ref.read(currentMembershipProvider)?.name ?? 'Workspace';
        final backup = await ref.read(backupDataSourceProvider).export(tenantId, name);
        final folder = await drive.ensureFolder();
        await drive.upload(folder, backupFileName(name, backup.createdAt), jsonEncode(backup.toJson()));

        // Keep the newest [keepBackups]; failing to tidy up is not an error.
        try {
          final all = await drive.list(folder);
          for (final old in all.skip(keepBackups)) {
            await drive.delete(old.id);
          }
        } on Object catch (e) {
          _log.warning('old backups not pruned: ${e.runtimeType}');
        }

        final now = DateTime.now();
        await ref.read(sharedPreferencesProvider).setString(_lastKey, now.toIso8601String());
        state = state.copyWith(lastBackupAt: now);
        return backup;
      });

  /// Backups in Drive, newest first.
  Future<List<DriveFile>> listBackups() => _run(() async {
        final drive = await _drive(interactive: true);
        return drive.list(await drive.ensureFolder());
      });

  /// Restores [file] into the current workspace — missing rows only. Refuses
  /// a backup from another workspace. Owner/admin only (RLS enforces it too).
  Future<RestoreReport> restore(DriveFile file) => _run(() async {
        final tenantId = _tenant();
        if (!(ref.read(currentRoleProvider)?.canWrite ?? false)) {
          throw const PermissionFailure(message: 'Only owners and admins can restore a backup.');
        }
        final drive = await _drive(interactive: true);
        final backup = WorkspaceBackup.fromJson(
          jsonDecode(await drive.download(file.id)) as Map<String, dynamic>,
        );
        if (backup.tenantId != tenantId) {
          throw ValidationFailure(
            'This backup is from the workspace "${backup.workspaceName}". '
            'Switch to that workspace to restore it.',
          );
        }
        return ref.read(backupDataSourceProvider).restoreMissing(tenantId, backup);
      });

  /// Called when the app opens: a silent backup if one is due. Never throws
  /// and never shows Google's picker.
  Future<void> autoBackupIfDue() async {
    final s = state;
    if (s.busy || !autoBackupDue(enabled: s.autoEnabled, last: s.lastBackupAt, now: DateTime.now())) {
      return;
    }
    if (ref.read(currentTenantIdProvider) == null || !ref.read(isOnlineProvider)) return;
    try {
      await backUpNow(interactive: false);
      _log.info('automatic Drive backup done');
    } on Object catch (e) {
      _log.warning('automatic Drive backup skipped: ${e.runtimeType}');
    }
  }

  Future<void> disconnect() async {
    await ref.read(driveAuthProvider).disconnect();
    await setAuto(false);
  }
}

final driveBackupProvider = NotifierProvider<DriveBackupController, DriveBackupState>(
  DriveBackupController.new,
  name: 'driveBackup',
);
