import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../reminders/presentation/status_tones.dart';
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
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          return AppPage(
            title: 'Recurring',
            subtitle: 'Salary, rent, EMIs and subscriptions',
            padBody: false,
            header: _Switcher(controller: controller),
            floatingActionButton: canWrite
                ? AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final type = controller.index == 0
                          ? RecurringType.income
                          : RecurringType.expense;
                      // The empty state already carries the same add action.
                      final hasItems = ref
                          .watch(recurringByTypeProvider(type))
                          .isNotEmpty;
                      if (!hasItems) return const SizedBox.shrink();
                      return AddFab(
                        label: 'Recurring',
                        onPressed: () => openRecurringForm(context, type: type),
                      );
                    },
                  )
                : null,
            body: items.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(
                e,
                onRetry: () => ref.invalidate(recurringItemsProvider),
              ),
              data: (_) => TabBarView(
                children: [
                  _RecurringList(
                    type: RecurringType.income,
                    canWrite: canWrite,
                  ),
                  _RecurringList(
                    type: RecurringType.expense,
                    canWrite: canWrite,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Round two-segment switcher (Income / Expenses) driving the tab controller.
class _Switcher extends StatelessWidget {
  const _Switcher({required this.controller});
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final selected = controller.animation!.value.round();
        Widget seg(int i, String label) {
          final on = selected == i;
          return Expanded(
            child: Semantics(
              button: true,
              selected: on,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.animateTo(i),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: const StadiumBorder(),
                    gradient: on ? palette.gradient : null,
                  ),
                  child: Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: on ? Colors.white : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: ShapeDecoration(
            color: palette.card,
            shape: StadiumBorder(side: BorderSide(color: palette.line)),
          ),
          child: Row(children: [seg(0, 'Income'), seg(1, 'Expenses')]),
        );
      },
    );
  }
}

/// Monthly equivalent of an item's amount (one-time items don't recur).
double _monthly(RecurringItem i) {
  final a = i.amount.amount.toDouble();
  return switch (i.frequency) {
    RecurringFrequency.monthly => a,
    RecurringFrequency.weekly => a * 52 / 12,
    RecurringFrequency.yearly => a / 12,
    RecurringFrequency.oneTime => 0,
  };
}

class _RecurringList extends ConsumerWidget {
  const _RecurringList({required this.type, required this.canWrite});
  final RecurringType type;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringByTypeProvider(type));
    final income = type == RecurringType.income;
    const padding = EdgeInsets.fromLTRB(
      AppSpacing.screenGutter,
      AppSpacing.sm,
      AppSpacing.screenGutter,
      96,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recurringItemsProvider);
        ref.invalidate(recurringRemindersProvider);
      },
      child: items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                CardEmpty(
                  icon: Icons.event_repeat_rounded,
                  title: income
                      ? 'No recurring income'
                      : 'No recurring expenses',
                  message: income
                      ? 'Add your salary or a rent you receive. FinRoot '
                            'prompts you to log it each period.'
                      : 'Add rent, an EMI or a subscription. FinRoot '
                            'prompts you to log it each period.',
                  actionLabel: canWrite ? 'Add one' : null,
                  onAction: canWrite
                      ? () => openRecurringForm(context, type: type)
                      : null,
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: padding,
              children: [
                _Summary(items: items, income: income),
                const SizedBox(height: AppSpacing.sm),
                for (final item in items)
                  _RecurringCard(item: item, canWrite: canWrite),
              ],
            ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.items, required this.income});
  final List<RecurringItem> items;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final total = items.fold<double>(0, (a, i) => a + _monthly(i));
    final next = items.first.daysUntilDue();
    final String nextText = switch (next) {
      < 0 => 'next one is ${-next}d overdue',
      0 => 'next one is due today',
      1 => 'next one is due tomorrow',
      _ => 'next one is due in ${next}d',
    };
    return MetricCard(
      eyebrow: income ? 'Monthly recurring in' : 'Monthly recurring out',
      figure: MoneyFormat.money(total.roundToDouble()),
      figureSuffix: 'a month',
      status:
          '${items.length} ${items.length == 1 ? 'item' : 'items'} · $nextText',
      statusColor: next < 0
          ? finance.expense
          : (income ? finance.income : null),
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.item, required this.canWrite});
  final RecurringItem item;
  final bool canWrite;

  static final ButtonStyle _compact = ButtonStyle(
    minimumSize: WidgetStateProperty.all(const Size.fromHeight(40)),
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 14),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final setting = ref.watch(reminderSettingForProvider(item.id));
    final days = item.daysUntilDue();
    final tileTone = item.isIncome
        ? StatusTone.mint(context)
        : StatusTone.coral(context);
    final dueTone = StatusTone.forDays(context, days);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: canWrite
            ? () => openRecurringForm(context, editing: item)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(
                  icon: item.isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  tint: tileTone.background,
                  color: tileTone.foreground,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category} · ${item.frequency.label}',
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
                const SizedBox(width: AppSpacing.md),
                AmountText.money(
                  item.amount,
                  signed: false,
                  type: item.isIncome ? TxnType.income : TxnType.expense,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                dueTone.pill(dueLabel(days)),
                if (setting.enabled)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: context.finance.brandText,
                    ),
                  ),
                const Spacer(),
                if (canWrite) ...[
                  ReminderBell(itemId: item.id, dueDate: item.nextDueDate),
                  RoundIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    size: 36,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ],
            ),
            if (canWrite) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                style: _compact,
                onPressed: () => _mark(context, ref),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(item.isIncome ? 'Mark received' : 'Mark paid'),
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
            style: AppButtonStyles.destructive,
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
