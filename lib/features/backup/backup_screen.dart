import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/time/relative_time.dart';
import '../../design/design.dart';
import '../sync/application/sync_engine.dart';
import '../workspace/application/workspace_providers.dart';
import 'backup_data.dart';
import 'drive_backup.dart';
import 'drive_client.dart';

final _stamp = DateFormat('d MMM yyyy, h:mm a');

/// Supabase sync + Google Drive backup, side by side.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  List<DriveFile>? _files;

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guard(Future<void> Function() body) async {
    try {
      await body();
    } on Failure catch (f) {
      if (mounted) _say(f.message);
    } on FormatException catch (e) {
      if (mounted) _say(e.message);
    }
  }

  Future<void> _backUp() => _guard(() async {
        final b = await ref.read(driveBackupProvider.notifier).backUpNow();
        if (!mounted) return;
        _say(b.skipped.isEmpty
            ? 'Backed up ${b.rowCount} records to Google Drive.'
            : 'Backed up ${b.rowCount} records. Left out: ${b.skipped.keys.join(', ')}.');
        if (_files != null) await _load();
      });

  Future<void> _load() => _guard(() async {
        final files = await ref.read(driveBackupProvider.notifier).listBackups();
        if (mounted) setState(() => _files = files);
      });

  Future<void> _restore(DriveFile f) => _guard(() async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Restore this backup?'),
            content: Text(
              'From ${_stamp.format(f.modified.toLocal())}.\n\n'
              'Anything in this backup that is missing now (for example deleted '
              'by mistake) is added back. Nothing that exists now is changed or '
              'removed, so newer edits are safe.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Restore')),
            ],
          ),
        );
        if (ok != true) return;
        final RestoreReport r = await ref.read(driveBackupProvider.notifier).restore(f);
        await ref.read(syncEngineProvider.notifier).syncNow(full: true, force: true);
        if (!mounted) return;
        _say(r.failed.isEmpty
            ? 'Restore finished. Missing records are back.'
            : 'Restore finished, except: ${r.failed.keys.join(', ')}.');
      });

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(driveBackupProvider);
    final sync = ref.watch(syncEngineProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync & backup')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter, AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.huge,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.sync),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Live sync (FinRoot cloud)', style: tt.titleMedium)),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Keeps this phone and the web dashboard in step, all the time. '
                  '${sync.lastSyncedAt == null ? 'Not synced yet.' : 'Last synced ${RelativeTime.short(sync.lastSyncedAt!)}.'}',
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => ref.read(syncEngineProvider.notifier).syncNow(full: true, force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Sync now'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.add_to_drive),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Google Drive backup', style: tt.titleMedium)),
                ]),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A copy of everything in this workspace, saved as a file in the '
                  '"$backupFolderName" folder of your own Google Drive. FinRoot can '
                  'only see the files it makes there.',
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.lastBackupAt == null
                      ? 'No backup from this phone yet.'
                      : 'Last backup ${_stamp.format(s.lastBackupAt!.toLocal())}.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: s.busy ? null : _backUp,
                  icon: s.busy
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(s.busy ? 'Working…' : 'Back up now'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Back up once a day'),
                  subtitle: const Text('When you open FinRoot and the last backup is over a day old.'),
                  value: s.autoEnabled,
                  onChanged: (v) => ref.read(driveBackupProvider.notifier).setAuto(v),
                ),
              ],
            ),
          ),
          const SectionHeader('Backups in Google Drive'),
          if (_files == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: s.busy ? null : _load,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Show my backups'),
              ),
            )
          else if (_files!.isEmpty)
            Text('No backups yet.', style: tt.bodyMedium)
          else
            for (final f in _files!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(_stamp.format(f.modified.toLocal())),
                subtitle: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: canWrite
                    ? TextButton(onPressed: s.busy ? null : () => _restore(f), child: const Text('Restore'))
                    : null,
              ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: s.busy
                ? null
                : () => _guard(() async {
                      await ref.read(driveBackupProvider.notifier).disconnect();
                      if (mounted) setState(() => _files = null);
                    }),
            child: const Text('Disconnect Google Drive'),
          ),
        ],
      ),
    );
  }
}
