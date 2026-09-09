import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../application/sync_engine.dart';
import '../application/sync_status.dart';

/// App-wide sync notice. Renders nothing unless the state is one a person
/// should see — offline (informational) or a failed sync (offer a retry).
/// Mounted once, at the top of the shell body.
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(syncStatusProvider);
    if (!view.showBanner) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final isProblem = view.tone == SyncTone.problem;

    final background = isProblem
        ? scheme.errorContainer
        : finance.warningContainer;
    final foreground = isProblem
        ? scheme.onErrorContainer
        : scheme.onSurface;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                isProblem ? Icons.sync_problem_rounded : Icons.cloud_off_rounded,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isProblem
                      ? _problemText(view)
                      : 'You\'re offline — changes save on this device and '
                            'sync when you reconnect.',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: foreground),
                ),
              ),
              if (isProblem) ...[
                const SizedBox(width: AppSpacing.xs),
                TextButton(
                  onPressed: () =>
                      ref.read(syncEngineProvider.notifier).retryFailed(),
                  style: TextButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: const Size(64, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _problemText(SyncStatusView view) {
    final n = view.failedCount;
    if (n <= 0) return 'The last sync didn\'t finish.';
    return n == 1
        ? '1 change didn\'t sync.'
        : '$n changes didn\'t sync.';
  }
}

/// Compact sync state for the Home header. Always renders something.
class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(syncStatusProvider);
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme.labelSmall;

    final (IconData? icon, String label, Color color) = switch (view.tone) {
      SyncTone.offline => (
        Icons.cloud_off_rounded,
        'Offline',
        scheme.onSurfaceVariant,
      ),
      SyncTone.problem => (
        Icons.sync_problem_rounded,
        view.failedCount > 0 ? '${view.unsyncedCount} didn\'t sync' : 'Sync failed',
        scheme.error,
      ),
      SyncTone.working => (null, 'Syncing…', scheme.onSurfaceVariant),
      SyncTone.waiting => (
        Icons.cloud_upload_rounded,
        view.pendingCount == 1
            ? '1 change to sync'
            : '${view.pendingCount} changes to sync',
        scheme.onSurfaceVariant,
      ),
      SyncTone.synced => (
        Icons.cloud_done_rounded,
        view.lastSyncedAt == null
            ? 'Up to date'
            : 'Synced ${RelativeTime.short(view.lastSyncedAt!)}',
        scheme.onSurfaceVariant,
      ),
    };

    return Semantics(
      label: 'Sync status: $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: color)
          else
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: t?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
