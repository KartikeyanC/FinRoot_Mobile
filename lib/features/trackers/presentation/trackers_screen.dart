import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../../navigation/pane_selection.dart';
import '../../../navigation/two_pane.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/trackers_providers.dart';
import '../domain/tracker_draft.dart';
import '../domain/tracker_spend.dart';
import 'tracker_detail_screen.dart';
import 'tracker_form_sheet.dart';
import 'widgets/tracker_progress.dart';

/// Trackers (M9) — an optional contextual dimension on a transaction, never a
/// ledger (ADR-0010). The `trackers` menu is a real paywall (ADR-0002); when
/// it is not in the workspace's effective menus this tab shows a locked state.
///
/// Phone: tap a card to push the detail route. Tablet (expanded): a two-pane
/// list/detail (M16).
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

    final twoPane = AppBreakpoints.of(context).showsTwoPane;
    final statuses = ref.watch(trackerStatusFilterProvider);
    final list = ref.watch(trackersWithSpendProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final selectedId = twoPane ? ref.watch(selectedTrackerIdProvider) : null;

    void openTracker(String id) {
      if (twoPane) {
        ref.read(selectedTrackerIdProvider.notifier).select(id);
      } else {
        context.push('/tracker/$id');
      }
    }

    // Swipe order matches the chip row. With several statuses ticked, the
    // swipe starts from the first one and narrows to a single status.
    const order = [
      TrackerStatus.active,
      TrackerStatus.completed,
      TrackerStatus.archived,
    ];
    final swipeIndex = order
        .indexWhere((s) => statuses.contains(s.name))
        .clamp(0, order.length - 1);

    final listPane = Column(
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
                onToggle: (s) =>
                    ref.read(trackerStatusFilterProvider.notifier).toggle(s),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SwipeTabs(
            index: swipeIndex,
            count: order.length,
            onChanged: (i) => ref
                .read(trackerStatusFilterProvider.notifier)
                .only({order[i].name}),
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
                        itemBuilder: (_, i) => _TrackerCard(
                          trackers[i],
                          selected: trackers[i].tracker.id == selectedId,
                          onTap: () => openTracker(trackers[i].tracker.id),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );

    final fab = canWrite
        ? GradientExtendedFab(
            onPressed: () => openTrackerForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Tracker'),
          )
        : null;

    if (!twoPane) {
      return Scaffold(
        floatingActionButton: fab,
        body: SafeArea(bottom: false, child: listPane),
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: SafeArea(
        bottom: false,
        child: TwoPane(
          list: listPane,
          detail: selectedId == null
              ? null
              : TrackerDetailView(
                  key: ValueKey(selectedId),
                  trackerId: selectedId,
                  inPane: true,
                  onDeleted: () =>
                      ref.read(selectedTrackerIdProvider.notifier).clear(),
                ),
          placeholder: const PaneWaiting(
            message: 'Pick a tracker to see its progress and transactions.',
            icon: Icons.donut_large_outlined,
          ),
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
      child: RevealWhenSelected(
        selected: selected.contains(s.name),
        child: FilterChip(
          label: Text(s.label),
          selected: selected.contains(s.name),
          onSelected: (_) => onToggle(s.name),
        ),
      ),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(TrackerStatus.active),
          chip(TrackerStatus.completed),
          chip(TrackerStatus.archived),
        ],
      ),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard(this.t, {required this.selected, required this.onTap});
  final TrackerWithSpend t;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  trackerTypeIcon(t.tracker.type),
                  size: 18,
                  color: context.finance.brandText,
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
