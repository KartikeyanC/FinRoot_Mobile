import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
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
import 'widgets/tracker_status_pill.dart';

//// Trackers (M9) — an optional contextual dimension on a transaction, never a
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

    // Swipe order matches the pill row. With several statuses ticked, the
    // swipe starts from the first one and narrows to a single status.
    const order = [
      TrackerStatus.active,
      TrackerStatus.completed,
      TrackerStatus.archived,
    ];
    final swipeIndex = order
        .indexWhere((s) => statuses.contains(s.name))
        .clamp(0, order.length - 1);

    final trackers = list.value;
    // The empty state already offers "Create a tracker"; never show two adds.
    final showFab =
        canWrite && (trackers == null || trackers.isNotEmpty);

    final listPane = AppPage(
      title: 'Trackers',
      subtitle: 'Totals for projects and trips, without moving money',
      floatingActionButton: showFab
          ? AddFab(label: 'Tracker', onPressed: () => openTrackerForm(context))
          : null,
      header: FilterPills<TrackerStatus>(
        options: [
          for (final s in order) FilterPill<TrackerStatus>(s, s.label),
        ],
        selected: order[swipeIndex],
        onSelected: (s) => ref
            .read(trackerStatusFilterProvider.notifier)
            .only({s.name}),
      ),
      padBody: false,
      body: SwipeTabs(
        index: swipeIndex,
        count: order.length,
        onChanged: (i) => ref
            .read(trackerStatusFilterProvider.notifier)
            .only({order[i].name}),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(trackerSpendRowsProvider);
            await ref.read(syncEngineProvider.notifier).syncNow(force: true);
          },
          child: list.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(e),
            data: (trackers) => trackers.isEmpty
                ? _EmptyTrackers(canWrite: canWrite, status: order[swipeIndex])
                : _TrackerList(
                    trackers: trackers,
                    selectedId: selectedId,
                    onOpen: openTracker,
                  ),
          ),
        ),
      ),
    );

    if (!twoPane) return listPane;

    return Scaffold(
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

class _TrackerList extends StatelessWidget {
  const _TrackerList({
    required this.trackers,
    required this.selectedId,
    required this.onOpen,
  });

  final List<TrackerWithSpend> trackers;
  final String? selectedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    var spent = Money.zero();
    var budget = Money.zero();
    for (final t in trackers) {
      spent += t.spent;
      if (t.hasBudget) budget += t.tracker.budget!;
    }
    final palette = context.palette;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        96,
      ),
      children: [
        StatStrip([
          Stat('${trackers.length}', 'Count'),
          Stat(spent.formatShort(), 'Spent'),
          Stat(budget.isZero ? '—' : budget.formatShort(), 'Budget'),
        ]),
        const SizedBox(height: AppSpacing.md),
        for (final t in trackers)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _TrackerCard(
              t,
              selected: t.tracker.id == selectedId,
              borderColor: palette.accent,
              onTap: () => onOpen(t.tracker.id),
            ),
          ),
      ],
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard(
    this.t, {
    required this.selected,
    required this.borderColor,
    required this.onTap,
  });
  final TrackerWithSpend t;
  final bool selected;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: selected ? Border.all(color: borderColor, width: 1.5) : null,
      ),
      child: AppCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(icon: trackerTypeIcon(t.tracker.type)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trackerDisplayLabel(t.tracker.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title.copyWith(
                          color: palette.ink,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t.txnCount == 1
                            ? '1 transaction'
                            : '${t.txnCount} transactions',
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TrackerStatusPill(t),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TrackerProgress(t, compact: true),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrackers extends StatelessWidget {
  const _EmptyTrackers({required this.canWrite, required this.status});
  final bool canWrite;
  final TrackerStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == TrackerStatus.active;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xl,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        EmptyView(
          icon: Icons.donut_large_outlined,
          title: 'No trackers here',
          message: active
              ? 'A tracker totals what a project or trip costs, without '
                    'moving money out of your accounts.'
              : 'No ${status.label.toLowerCase()} trackers yet.',
          action: canWrite && active
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
