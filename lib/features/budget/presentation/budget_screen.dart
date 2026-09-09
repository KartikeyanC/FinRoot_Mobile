import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/budget_providers.dart';
import '../domain/budget_spend.dart';
import 'allocation_sheet.dart';

/// Budget (M10) — the 7-jar monthly system. Menu-gated (ADR-0002). Spend is
/// server-derived (`budget_spend`); allocations go through
/// `budget_set_allocation`.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.budget)) == MenuStatus.locked;
    if (locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Budget')),
        body: const MenuLockedView(
          feature: 'Budgets',
          icon: Icons.pie_chart_outline,
        ),
      );
    }

    final period = ref.watch(budgetPeriodProvider);
    final buckets = ref.watch(budgetsWithSpendProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.sm,
              left: AppSpacing.lg,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('MMMM yyyy').format(period),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(budgetSpendRowsProvider);
          await ref.read(syncEngineProvider.notifier).syncNow(force: true);
        },
        child: buckets.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            final totalAllocated = list.fold(
              Money.zero(),
              (s, b) => s + b.budget.allocated,
            );
            final totalSpent = list.fold(
              Money.zero(),
              (s, b) => s + b.spent,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.lg,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      _Total(label: 'Allocated', amount: totalAllocated),
                      const SizedBox(width: AppSpacing.xl),
                      _Total(label: 'Spent', amount: totalSpent),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final b in list)
                  _BucketTile(b: b, canWrite: canWrite),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.amount});
  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AmountText.money(amount, size: AmountSize.large, signed: false),
      ],
    );
  }
}

class _BucketTile extends StatelessWidget {
  const _BucketTile({required this.b, required this.canWrite});
  final BudgetWithSpend b;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final allocated = b.budget.allocated;
    final hasAllocation = allocated.isPositive;

    final barColor = b.isOverBudget
        ? finance.expense
        : (b.utilization >= 85 ? finance.warning : scheme.primary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: canWrite ? () => openAllocationSheet(context, b) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(b.budget.bucket, style: tt.titleSmall)),
                if (hasAllocation)
                  Text(
                    '${b.spent.formatShort()} / ${allocated.formatShort()}',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    canWrite ? 'Set a budget' : 'No budget',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (hasAllocation) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: (b.utilization / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                b.isNonExpense
                    ? 'Money set aside — no tracked spend'
                    : b.isOverBudget
                    ? '${b.remaining.abs.formatShort()} over'
                    : '${b.remaining.formatShort()} left',
                style: tt.bodySmall?.copyWith(
                  color: b.isOverBudget
                      ? finance.expense
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
