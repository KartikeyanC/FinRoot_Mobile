import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/reminders_editor_controller.dart';
import '../application/reminders_providers.dart';
import '../domain/reminder.dart';
import 'reminder_form_sheet.dart';
import 'status_tones.dart';

/// Standalone reminders (M12) — a chronological list of scheduled money events
/// (bills, buffers, maturities). Menu-gated (`reminders`), online-only, not
/// cached. Debt-installment linkage, grace windows and liquidity checks stay
/// web-only in V1 (see the M12 report); a web-created reminder still displays.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.reminders)) ==
        MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Reminders',
        body: MenuLockedView(
          feature: 'Reminders',
          icon: Icons.notifications_none,
        ),
      );
    }

    final reminders = ref.watch(remindersProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasAny = reminders.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Reminders',
      subtitle: 'Bills, buffers and maturities',
      padBody: false,
      // The empty state carries its own add action; the FAB only appears once
      // there is something in the list.
      floatingActionButton: canWrite && hasAny
          ? AddFab(
              label: 'Reminder',
              onPressed: () => openReminderForm(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(remindersProvider),
        child: reminders.when(
          loading: () => const LoadingView(),
          error: (e, _) =>
              ErrorView(e, onRetry: () => ref.invalidate(remindersProvider)),
          data: (list) {
            if (list.isEmpty) return _Empty(canWrite: canWrite);
            return _RemindersList(list: list, canWrite: canWrite);
          },
        ),
      ),
    );
  }
}

class _RemindersList extends StatelessWidget {
  const _RemindersList({required this.list, required this.canWrite});
  final List<Reminder> list;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final sorted = [...list]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final open = sorted.where((r) => !r.isCompleted).toList();
    final overdue = open.where((r) => r.daysUntilDue() < 0).toList();
    final week = open.where((r) {
      final d = r.daysUntilDue();
      return d >= 0 && d <= 7;
    }).toList();
    final later = open.where((r) => r.daysUntilDue() > 7).toList();
    final done = sorted.where((r) => r.isCompleted).toList();
    final finance = context.finance;

    Widget group(String title, List<Reminder> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title),
              for (final r in items)
                _ReminderCard(reminder: r, canWrite: canWrite),
            ],
          );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        96,
      ),
      children: [
        StatStrip([
          Stat('${week.length}', 'Due this week'),
          Stat(
            '${overdue.length}',
            'Overdue',
            color: overdue.isEmpty ? null : finance.expense,
          ),
          Stat('${later.length}', 'Upcoming'),
        ]),
        group('Overdue', overdue),
        group('This week', week),
        group('Later', later),
        group('Done', done),
      ],
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder, required this.canWrite});
  final Reminder reminder;
  final bool canWrite;

  static final ButtonStyle _compact = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size(0, 36)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 14),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final done = reminder.isCompleted;
    final days = reminder.daysUntilDue();
    final tone = done
        ? StatusTone.mint(context)
        : StatusTone.forDays(context, days);
    final pill = done
        ? tone.pill('Completed', dot: true)
        : tone.pill(dueLabel(days));

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: done ? 0.7 : 1,
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          onTap: canWrite && !done
              ? () => openReminderForm(context, editing: reminder)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: reminder.context.icon,
                    tint: tone.background,
                    color: tone.foreground,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyStrong.copyWith(
                            color: palette.ink,
                            fontSize: 15,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${DateFormat('EEE, d MMM').format(reminder.dueDate)}'
                          ' · ${reminder.context.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: palette.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reminder.amount != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    AmountText.money(reminder.amount!, signed: false),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  pill,
                  const Spacer(),
                  if (canWrite) ...[
                    if (!done)
                      OutlinedButton.icon(
                        style: _compact,
                        onPressed: () => _act(
                          context,
                          ref,
                          () => ref
                              .read(remindersEditorControllerProvider)
                              .complete(reminder.id),
                          'Marked done',
                        ),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Done'),
                      )
                    else
                      TextButton.icon(
                        style: _compact,
                        onPressed: () => _act(
                          context,
                          ref,
                          () => ref
                              .read(remindersEditorControllerProvider)
                              .reopen(reminder.id),
                          'Reopened',
                        ),
                        icon: const Icon(Icons.undo_rounded, size: 18),
                        label: const Text('Reopen'),
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    RoundIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete',
                      size: 36,
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String ok,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${reminder.title}"?'),
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
    if (confirmed != true) return;
    try {
      await ref.read(remindersEditorControllerProvider).delete(reminder.id);
      messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        CardEmpty(
          icon: Icons.notifications_none_rounded,
          title: 'No reminders yet',
          message:
              'Start with a bill, like your credit card due on the 5th. '
              'FinRoot nudges you before it is due.',
          actionLabel: canWrite ? 'Add reminder' : null,
          onAction: canWrite ? () => openReminderForm(context) : null,
        ),
      ],
    );
  }
}
