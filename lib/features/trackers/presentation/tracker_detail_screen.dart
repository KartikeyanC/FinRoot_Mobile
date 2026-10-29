import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../transactions/presentation/transaction_detail_sheet.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/tracker_editor_controller.dart';
import '../application/trackers_providers.dart';
import '../domain/tracker_draft.dart';
import '../domain/tracker_spend.dart';
import 'assign_transactions_sheet.dart';
import 'tracker_form_sheet.dart';
import 'widgets/tracker_progress.dart';

/// Full-screen tracker detail — the phone route (`/tracker/:id`) and any deep
/// link. On a tablet the Trackers tab shows [TrackerDetailView] inline in its
/// second pane instead (M16).
class TrackerDetailScreen extends ConsumerWidget {
  const TrackerDetailScreen({super.key, required this.trackerId});
  final String trackerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackerWithSpendProvider(trackerId));
    final trackerAsync = ref.watch(trackerByIdProvider(trackerId));

    if (t == null) {
      return Scaffold(
        appBar: AppBar(),
        body: trackerAsync.isLoading
            ? const LoadingView()
            : const EmptyView(
                icon: Icons.donut_large_outlined,
                title: 'Tracker not found',
                message: 'It may have been deleted.',
              ),
      );
    }

    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final status = TrackerStatus.fromWire(t.tracker.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(trackerDisplayLabel(t.tracker.name)),
        actions: [
          if (canWrite)
            TrackerActionsMenu(
              tracker: t,
              status: status,
              onDeleted: () => context.pop(),
            ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openAssignTransactions(context, trackerId),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Assign'),
            )
          : null,
      body: TrackerDetailView(trackerId: trackerId),
    );
  }
}

/// The tracker detail body — progress, dates, tagged transactions. [inPane]
/// adds a compact header (title + Assign + actions) that the full-screen route
/// gets from its [AppBar] and FAB instead. [onDeleted] runs after a successful
/// delete — pop the route, or clear the pane selection.
class TrackerDetailView extends ConsumerWidget {
  const TrackerDetailView({
    super.key,
    required this.trackerId,
    this.onDeleted,
    this.inPane = false,
  });

  final String trackerId;
  final VoidCallback? onDeleted;
  final bool inPane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trackerWithSpendProvider(trackerId));
    final trackerAsync = ref.watch(trackerByIdProvider(trackerId));
    final txns = ref.watch(trackerTransactionsProvider(trackerId));
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final tt = Theme.of(context).textTheme;

    if (t == null) {
      return Center(
        child: trackerAsync.isLoading
            ? const LoadingView()
            : const EmptyView(
                icon: Icons.donut_large_outlined,
                title: 'Tracker not found',
                message: 'It may have been deleted.',
              ),
      );
    }

    final status = TrackerStatus.fromWire(t.tracker.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        if (inPane)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trackerDisplayLabel(t.tracker.name),
                    style: tt.titleLarge,
                  ),
                ),
                if (canWrite) ...[
                  IconButton(
                    tooltip: 'Assign transactions',
                    onPressed: () =>
                        openAssignTransactions(context, trackerId),
                    icon: const Icon(Icons.playlist_add),
                  ),
                  TrackerActionsMenu(
                    tracker: t,
                    status: status,
                    onDeleted: onDeleted,
                  ),
                ],
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      trackerTypeIcon(t.tracker.type),
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      t.tracker.type,
                      style: tt.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (status != TrackerStatus.active) ...[
                      const Spacer(),
                      Text(status.label, style: tt.labelSmall),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TrackerProgress(t),
                if (t.inflow.isPositive) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Text(
                        'Income tagged here (kept separate)',
                        style: tt.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      AmountText.money(t.inflow, type: TxnType.income),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  _dateLine(t),
                  style: tt.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((t.tracker.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(t.tracker.description!.trim(), style: tt.bodyMedium),
                ],
              ],
            ),
          ),
          const SectionHeader('Transactions'),
          txns.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: LoadingView(),
            ),
            error: (e, st) => ErrorView(e, stackTrace: st),
            data: (list) => list.isEmpty
                ? const AppCard(
                    child: Text(
                      'No transactions tagged to this tracker yet. Use '
                      'Assign, or set the tracker when you record one.',
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < list.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          TransactionTile(
                            list[i],
                            onTap: () =>
                                openTransactionDetail(context, list[i].id),
                          ),
                        ],
                      ],
                    ),
                  ),
        ),
      ],
    );
  }

  String _dateLine(TrackerWithSpend t) {
    final start = RelativeTime.dayLabel(t.tracker.startDate);
    final end = t.tracker.endDate;
    return end == null
        ? 'Started $start · open-ended'
        : 'Started $start · ends ${RelativeTime.dayLabel(end)}';
  }
}

/// The edit / complete / archive / reopen / delete menu, shared by the
/// full-screen route (in its AppBar) and the tablet pane header.
class TrackerActionsMenu extends ConsumerWidget {
  const TrackerActionsMenu({
    super.key,
    required this.tracker,
    required this.status,
    required this.onDeleted,
  });

  final TrackerWithSpend tracker;
  final TrackerStatus status;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (v) => _onAction(context, ref, v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (status != TrackerStatus.completed)
          const PopupMenuItem(
            value: 'complete',
            child: Text('Mark completed'),
          ),
        if (status != TrackerStatus.archived)
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
        if (status != TrackerStatus.active)
          const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(trackerEditorControllerProvider);
    final t = tracker;
    try {
      switch (action) {
        case 'edit':
          await openTrackerForm(context, editing: t.tracker);
        case 'complete':
          await controller.setStatus(t.tracker.id, TrackerStatus.completed);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '"${t.tracker.name}" completed · '
                'final total ${t.spent.formatShort()}',
              ),
            ),
          );
        case 'archive':
          await controller.setStatus(t.tracker.id, TrackerStatus.archived);
        case 'reopen':
          await controller.setStatus(t.tracker.id, TrackerStatus.active);
        case 'delete':
          final ok = await _confirmDelete(context, t.tracker.name);
          if (ok != true) return;
          await controller.delete(t.tracker.id);
          onDeleted?.call();
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Tracker deleted. Your transactions were not changed.',
              ),
            ),
          );
      }
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text(
          'The tracker is removed. Every transaction it grouped stays exactly '
          'where it is — only the label goes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
