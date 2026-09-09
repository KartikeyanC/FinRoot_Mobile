import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/trackers_providers.dart';
import '../domain/tracker_draft.dart';
import '../domain/tracker_spend.dart';
import 'tracker_form_sheet.dart';
import 'widgets/tracker_progress.dart';

/// Trackers (M9) — an optional contextual dimension on a transaction, never a
/// ledger (ADR-0010). The `trackers` menu is a real paywall (ADR-0002); when
/// it is not in the workspace's effective menus this tab shows a locked state.
class TrackersScreen extends ConsumerWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.trackers)) ==
        MenuStatus.locked;
    if (locked) {
      return const Scaffold(
        body: MenuLockedView(
          feature: 'Trackers',
          icon: Icons.donut_large_outlined,
        ),
      );
    }

    final statuses = ref.watch(trackerStatusFilterProvider);
    final list = ref.watch(trackersWithSpendProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openTrackerForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Tracker'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Trackers',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StatusChips(
                    selected: statuses,
                    onToggle: (s) => ref
                        .read(trackerStatusFilterProvider.notifier)
                        .toggle(s),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(trackerSpendRowsProvider);
                  await ref
                      .read(syncEngineProvider.notifier)
                      .syncNow(force: true);
                },
                child: list.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(e),
                  data: (trackers) => trackers.isEmpty
                      ? _EmptyTrackers(canWrite: canWrite)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenGutter,
                            AppSpacing.sm,
                            AppSpacing.screenGutter,
                            AppSpacing.huge,
                          ),
                          itemCount: trackers.length,
                          itemBuilder: (_, i) => _TrackerCard(trackers[i]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    Widget chip(TrackerStatus s) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(s.label),
        selected: selected.contains(s.name),
        onSelected: (_) => onToggle(s.name),
      ),
    );
    return Row(
      children: [
        chip(TrackerStatus.active),
        chip(TrackerStatus.completed),
        chip(TrackerStatus.archived),
      ],
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard(this.t);
  final TrackerWithSpend t;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push('/tracker/${t.tracker.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  trackerTypeIcon(t.tracker.type),
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trackerDisplayLabel(t.tracker.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium,
                  ),
                ),
                if (t.tracker.status != 'active')
                  Text(
                    TrackerStatus.fromWire(t.tracker.status).label,
                    style: tt.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TrackerProgress(t, compact: true),
            const SizedBox(height: AppSpacing.xs),
            Text(
              t.txnCount == 1 ? '1 transaction' : '${t.txnCount} transactions',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrackers extends StatelessWidget {
  const _EmptyTrackers({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyView(
          icon: Icons.donut_large_outlined,
          title: 'No trackers here',
          message:
              'A tracker totals what a project or trip costs, without moving '
              'money out of your accounts.',
          action: canWrite
              ? FilledButton(
                  onPressed: () => openTrackerForm(context),
                  child: const Text('Create a tracker'),
                )
              : null,
        ),
      ],
    );
  }
}
