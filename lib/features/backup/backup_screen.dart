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
    } on Object catch (e) {
      // Anything else used to escape here, and the button just did nothing.
      if (mounted) _say('Drive backup failed: $e');
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
    final palette = context.palette;
    final finance = context.finance;
    final lastBackup = s.lastBackupAt;
    final age = lastBackup == null
        ? null
        : DateTime.now().difference(lastBackup.toLocal());
    final stale = age == null || age.inDays >= 7;

    return AppPage(
      title: 'Sync & backup',
      subtitle: 'Keep your data safe and in step',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          MetricCard(
            eyebrow: 'Last backup to Google Drive',
            figure: lastBackup == null
                ? 'Never'
                : RelativeTime.short(lastBackup),
            status: lastBackup == null
                ? 'No backup from this phone yet.'
                : _stamp.format(lastBackup.toLocal()),
            statusColor: stale ? finance.warning : finance.income,
            action: PillButton(
              label: s.busy ? 'Working…' : 'Back up now',
              icon: Icons.cloud_upload_outlined,
              onPressed: s.busy ? null : _backUp,
              expand: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Back up once a day',
                style: AppTypography.bodyStrong.copyWith(color: palette.ink),
              ),
              subtitle: const Text(
                'When you open FinRoot and the last backup is over a day old.',
              ),
              value: s.autoEnabled,
              onChanged: (v) =>
                  ref.read(driveBackupProvider.notifier).setAuto(v),
            ),
          ),
          const SectionTitle('Live sync'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(icon: Icons.sync_rounded),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FinRoot cloud',
                            style: AppTypography.bodyStrong.copyWith(
                              color: palette.ink,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            sync.lastSyncedAt == null
                                ? 'Not synced yet'
                                : 'Last synced ${RelativeTime.short(sync.lastSyncedAt!)}',
                            style: AppTypography.label.copyWith(
                              color: palette.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Keeps this phone and the web dashboard in step, all the time.',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(syncEngineProvider.notifier)
                      .syncNow(full: true, force: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Sync now'),
                ),
              ],
            ),
          ),
          const SectionTitle('Backups in Google Drive'),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md, left: 4),
            child: Text(
              'A copy of everything in this workspace, saved in the '
              '"$backupFolderName" folder of your own Google Drive. FinRoot '
              'can only see the files it makes there.',
              style: AppTypography.body.copyWith(color: palette.muted),
            ),
          ),
          if (_files == null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: s.busy ? null : _load,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Show my backups'),
              ),
            )
          else if (_files!.isEmpty)
            const CardEmpty(
              icon: Icons.cloud_off_outlined,
              title: 'No backups yet',
              message: 'Tap Back up now above to make your first one.',
            )
          else
            for (final f in _files!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListRow(
                  icon: Icons.description_outlined,
                  title: _stamp.format(f.modified.toLocal()),
                  subtitle: f.name,
                  trailing: canWrite
                      ? OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onPressed: s.busy ? null : () => _restore(f),
                          child: const Text('Restore'),
                        )
                      : null,
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: TextButton(
              onPressed: s.busy
                  ? null
                  : () => _guard(() async {
                      await ref.read(driveBackupProvider.notifier).disconnect();
                      if (mounted) setState(() => _files = null);
                    }),
              child: const Text('Disconnect Google Drive'),
            ),
          ),
        ],
      ),
    );
  }
}
