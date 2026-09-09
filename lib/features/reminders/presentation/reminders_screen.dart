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
      return Scaffold(
        appBar: AppBar(title: const Text('Reminders')),
        body: const MenuLockedView(
          feature: 'Reminders',
          icon: Icons.notifications_none,
        ),
      );
    }

    final reminders = ref.watch(remindersProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openReminderForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Reminder'),
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
            final sorted = [...list]..sort((a, b) {
              if (a.isCompleted != b.isCompleted) {
                return a.isCompleted ? 1 : -1;
              }
              return a.dueDate.compareTo(b.dueDate);
            });
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                for (final r in sorted)
                  _ReminderCard(reminder: r, canWrite: canWrite),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReminderCard extends ConsumerWidget {
  const _ReminderCard({required this.reminder, required this.canWrite});
  final Reminder reminder;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final done = reminder.isCompleted;
    final days = reminder.daysUntilDue();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: done ? 0.55 : 1,
        child: AppCard(
          onTap: canWrite && !done
              ? () => openReminderForm(context, editing: reminder)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(reminder.context.icon, size: 18,
                      color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (reminder.amount != null)
                    AmountText.money(reminder.amount!, signed: false),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${DateFormat('EEE, d MMM yyyy').format(reminder.dueDate)} · '
                '${reminder.context.label}',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                done
                    ? 'Completed'
                    : switch (days) {
                        < 0 => '${-days}d overdue',
                        0 => 'Due today',
                        1 => 'Due tomorrow',
                        _ => 'Due in ${days}d',
                      },
                style: tt.labelMedium?.copyWith(
                  color: !done && days <= 2 ? finance.expense
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (canWrite) ...[
                const Divider(height: AppSpacing.xl),
                Row(
                  children: [
                    if (!done)
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _act(context, ref,
                              () => ref
                                  .read(remindersEditorControllerProvider)
                                  .complete(reminder.id),
                              'Marked done'),
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Done'),
                        ),
                      )
                    else
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _act(context, ref,
                              () => ref
                                  .read(remindersEditorControllerProvider)
                                  .reopen(reminder.id),
                              'Reopened'),
                          icon: const Icon(Icons.undo, size: 18),
                          label: const Text('Reopen'),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref,
      Future<void> Function() action, String ok) async {
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
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyView(
          icon: Icons.notifications_none,
          title: 'No reminders yet',
          message:
              'Schedule a bill, a buffer check before a SIP debits, or a '
              'deposit maturity — the app nudges you before each one.',
          action: canWrite
              ? FilledButton(
                  onPressed: () => openReminderForm(context),
                  child: const Text('Add a reminder'),
                )
              : null,
        ),
      ],
    );
  }
}
