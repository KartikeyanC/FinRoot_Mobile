import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/recurring_editor_controller.dart';
import '../application/recurring_providers.dart';
import '../domain/recurring_item.dart';
import 'recurring_form_sheet.dart';
import 'reminder_popover.dart';

/// Recurring income / expense templates (M12). Online-only, not cached — the
/// web materialises a due item into a real transaction via the
/// `mark_recurring_generated` RPC; this screen calls the same RPC.
///
/// Not menu-gated: the web reaches this from the always-on Income / Expenses
/// pages.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringItemsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Recurring'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Income'), Tab(text: 'Expenses')],
          ),
        ),
        floatingActionButton: canWrite
            ? Builder(
                builder: (context) => FloatingActionButton.extended(
                  onPressed: () {
                    final type = DefaultTabController.of(context).index == 0
                        ? RecurringType.income
                        : RecurringType.expense;
                    openRecurringForm(context, type: type);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Recurring'),
                ),
              )
            : null,
        body: items.when(
          loading: () => const LoadingView(),
          error: (e, _) =>
              ErrorView(e, onRetry: () => ref.invalidate(recurringItemsProvider)),
          data: (_) => TabBarView(
            children: [
              _RecurringList(type: RecurringType.income, canWrite: canWrite),
              _RecurringList(type: RecurringType.expense, canWrite: canWrite),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurringList extends ConsumerWidget {
  const _RecurringList({required this.type, required this.canWrite});
  final RecurringType type;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringByTypeProvider(type));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recurringItemsProvider);
        ref.invalidate(recurringRemindersProvider);
      },
      child: items.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: AppSpacing.huge),
                EmptyView(
                  icon: Icons.event_repeat_outlined,
                  title: type == RecurringType.income
                      ? 'No recurring income'
                      : 'No recurring expenses',
                  message: type == RecurringType.income
                      ? 'Add a salary or a rent you receive and the app will '
                            'prompt you to log it each period.'
                      : 'Add rent, EMIs or subscriptions and the app will '
                            'prompt you to log them each period.',
                  action: canWrite
                      ? FilledButton(
                          onPressed: () =>
                              openRecurringForm(context, type: type),
                          child: const Text('Add one'),
                        )
                      : null,
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                for (final item in items)
                  _RecurringCard(item: item, canWrite: canWrite),
              ],
            ),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.item, required this.canWrite});
  final RecurringItem item;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final setting = ref.watch(reminderSettingForProvider(item.id));
    final days = item.daysUntilDue();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: canWrite
            ? () => openRecurringForm(context, editing: item)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${item.category} · ${item.frequency.label}',
                        style: tt.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AmountText.money(
                  item.amount,
                  signed: false,
                  type: item.isIncome ? TxnType.income : TxnType.expense,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _DueChip(days: days),
                const Spacer(),
                if (setting.enabled)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: context.finance.brandText,
                    ),
                  ),
              ],
            ),
            if (canWrite) ...[
              const Divider(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _mark(context, ref),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        item.isIncome ? 'Mark received' : 'Mark paid',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ReminderBell(itemId: item.id, dueDate: item.nextDueDate),
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
    );
  }

  Future<void> _mark(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(recurringEditorControllerProvider).markGenerated(item.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(item.isIncome ? 'Logged as received' : 'Logged as paid'),
        ),
      );
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove "${item.name}"?'),
        content: const Text(
          'This stops future occurrences. Transactions you already logged stay '
          'in your ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(recurringEditorControllerProvider).delete(item.id);
      messenger.showSnackBar(const SnackBar(content: Text('Removed')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final (String label, Color color) = switch (days) {
      < 0 => ('${-days}d overdue', finance.expense),
      0 => ('Due today', finance.expense),
      1 => ('Due tomorrow', scheme.onSurfaceVariant),
      <= 7 => ('Due in ${days}d', scheme.onSurfaceVariant),
      _ => ('Due in ${days}d', scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.chip,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
