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
import 'widgets/tracker_bar.dart';
import 'widgets/tracker_status_pill.dart';

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
      return AppPage(
        title: 'Tracker',
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

    return AppPage(
      title: trackerDisplayLabel(t.tracker.name),
      subtitle: t.tracker.type,
      actions: [
        if (canWrite)
          TrackerActionsMenu(
            tracker: t,
            status: status,
            onDeleted: () => context.pop(),
          ),
      ],
      floatingActionButton: canWrite
          ? AddFab(
              label: 'Assign',
              icon: Icons.playlist_add_rounded,
              onPressed: () => openAssignTransactions(context, trackerId),
            )
          : null,
      padBody: false,
      body: TrackerDetailView(trackerId: trackerId),
    );
  }
}

/// The tracker detail body — progress, dates, tagged transactions. [inPane]
/// adds a compact header (title + Assign + actions) that the full-screen route
/// gets from its [AppPage] title row and FAB instead. [onDeleted] runs after a
/// successful delete — pop the route, or clear the pane selection.
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
    final palette = context.palette;

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
    final finance = context.finance;
    final budget = t.tracker.budget;
    final String? statusLine;
    Color? statusColor;
    if (!t.hasBudget) {
      statusLine = 'No budget set';
    } else if (t.isOverBudget) {
      statusLine = '${t.remaining!.abs.formatShort()} over budget';
      statusColor = finance.expense;
    } else {
      statusLine = '${t.remaining!.formatShort()} left';
      statusColor = t.utilization >= 85 ? finance.warning : finance.income;
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        inPane ? AppSpacing.lg : AppSpacing.xs,
        AppSpacing.screenGutter,
        96,
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
                    style: AppTypography.display.copyWith(
                      color: palette.ink,
                      fontSize: 24,
                    ),
                  ),
                ),
                if (canWrite) ...[
                  RoundIconButton(
                    icon: Icons.playlist_add_rounded,
                    tooltip: 'Assign transactions',
                    onPressed: () =>
                        openAssignTransactions(context, trackerId),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TrackerActionsMenu(
                    tracker: t,
                    status: status,
                    onDeleted: onDeleted,
                  ),
                ],
              ],
            ),
          ),
        MetricCard(
          eyebrow: 'Spent so far',
          figure: t.spent.formatShort(),
          figureSuffix: budget != null && t.hasBudget
              ? 'of ${budget.formatShort()}'
              : null,
          status: statusLine,
          statusColor: statusColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (t.hasBudget) ...[
                TrackerBar(
                  fraction: t.spent.amount.toDouble() / budget!.amount.toDouble(),
                  color: t.isOverBudget
                      ? finance.expense
                      : (t.utilization >= 85
                            ? finance.warning
                            : palette.accent),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${t.utilization}% of budget used',
                  style: AppTypography.label.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TrackerStatusPill(t),
                  Text(
                    _dateLine(t),
                    style: AppTypography.label.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (t.inflow.isPositive || t.txnCount > 0) ...[
          const SizedBox(height: AppSpacing.md),
          StatStrip([
            Stat('${t.txnCount}', 'Tagged'),
            Stat(
              t.inflow.isPositive ? t.inflow.formatShort() : '—',
              'Income tagged',
              color: t.inflow.isPositive ? finance.income : null,
            ),
          ]),
        ],
        if ((t.tracker.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Text(
              t.tracker.description!.trim(),
              style: AppTypography.body.copyWith(color: palette.ink),
            ),
          ),
        ],
        const SectionTitle('Transactions'),
        txns.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: LoadingView(),
          ),
          error: (e, st) => ErrorView(e, stackTrace: st),
          data: (list) => list.isEmpty
              ? CardEmpty(
                  icon: Icons.receipt_long_rounded,
                  title: 'Nothing tagged yet',
                  message:
                      'No transactions tagged to this tracker yet. Use '
                      'Assign, or set the tracker when you record one.',
                  actionLabel: canWrite && !inPane ? 'Assign' : null,
                  onAction: canWrite && !inPane
                      ? () => openAssignTransactions(context, trackerId)
                      : null,
                )
              : Column(
                  children: [
                    for (final txn in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TransactionTile(
                          txn,
                          card: true,
                          onTap: () => openTransactionDetail(context, txn.id),
                        ),
                      ),
                  ],
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
/// full-screen route (in its title row) and the tablet pane header.
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
    final palette = context.palette;
    return PopupMenuButton<String>(
      tooltip: 'Tracker actions',
      onSelected: (v) => _onAction(context, ref, v),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.card,
          shape: BoxShape.circle,
          border: Border.all(color: palette.line),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 20, color: palette.ink),
      ),
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
