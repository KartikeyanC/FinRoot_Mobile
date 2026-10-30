import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/budget_providers.dart';
import '../domain/budget_buckets.dart';
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
      return const AppPage(
        title: 'Budget',
        body: MenuLockedView(
          feature: 'Budgets',
          icon: Icons.pie_chart_outline,
        ),
      );
    }

    final period = ref.watch(budgetPeriodProvider);
    final buckets = ref.watch(budgetsWithSpendProvider);
    final spendRows = ref.watch(budgetSpendRowsProvider).value ?? const [];
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return AppPage(
      title: 'Budget',
      subtitle: DateFormat('MMMM yyyy').format(period),
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(budgetSpendRowsProvider);
          await ref.read(syncEngineProvider.notifier).syncNow(force: true);
        },
        child: buckets.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.xs,
              AppSpacing.screenGutter,
              AppSpacing.huge,
            ),
            children: [
              _Headline(list: list, period: period),
              const SectionTitle('Your jars'),
              for (var i = 0; i < list.length; i++)
                _BucketCard(
                  b: list[i],
                  tone: _toneForBucket(context, list[i].budget.bucket, i),
                  categories: _categoriesFor(list[i], spendRows),
                  canWrite: canWrite,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Tone _toneForBucket(BuildContext c, String bucket, int index) =>
    switch (bucket) {
      'Needs' => Tones.sky(c),
      'Play' => Tones.butter(c),
      'Financial Freedom' => Tones.mint(c),
      'Long-Term Savings' => Tones.teal(c),
      'Education' => Tones.violet(c),
      'Giving' => Tones.rose(c),
      _ => Tones.accent(c),
    };

IconData _iconForBucket(String bucket) => switch (bucket) {
  'Needs' => Icons.home_outlined,
  'Play' => Icons.celebration_outlined,
  'Financial Freedom' => Icons.trending_up_rounded,
  'Long-Term Savings' => Icons.savings_outlined,
  'Education' => Icons.school_outlined,
  'Giving' => Icons.volunteer_activism_outlined,
  'Agri' => Icons.grass_outlined,
  _ => Icons.pie_chart_outline,
};

/// Per-category spend for one bucket, biggest first.
List<({String name, double total})> _categoriesFor(
  BudgetWithSpend b,
  List<BudgetSpendRow> rows,
) {
  final out = <String, double>{};
  for (final r in rows) {
    if (r.budgetId != b.budget.id) continue;
    if (r.category.isEmpty || bucketForCategory(r.category) != b.budget.bucket) {
      continue;
    }
    out[r.category] = (out[r.category] ?? 0) + r.total.toDouble();
  }
  final list = [
    for (final e in out.entries)
      if (e.value > 0) (name: e.key, total: e.value),
  ]..sort((a, b) => b.total.compareTo(a.total));
  return list.take(3).toList();
}

class _Headline extends StatelessWidget {
  const _Headline({required this.list, required this.period});
  final List<BudgetWithSpend> list;
  final DateTime period;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;

    // "Budget" for pace purposes is the spendable jars; savings jars are money
    // set aside, so they never show tracked spend.
    final spendable = [for (final b in list) if (!b.isNonExpense) b];
    final allocated = spendable.fold(Money.zero(), (s, b) => s + b.budget.allocated);
    final spent = spendable.fold(Money.zero(), (s, b) => s + b.spent);
    final totalAllocated = list.fold(Money.zero(), (s, b) => s + b.budget.allocated);

    String status;
    Color color;
    if (!allocated.isPositive) {
      status = totalAllocated.isPositive
          ? 'No spending budget set yet'
          : 'Set an amount for each jar to start';
      color = palette.muted;
    } else {
      final remaining = allocated - spent;
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final elapsed = now.day / daysInMonth;
      final used = spent.amount.toDouble() / allocated.amount.toDouble();
      if (remaining.amount < Decimal.zero) {
        status = '${remaining.abs.formatShort()} over budget';
        color = finance.expense;
      } else if (used > elapsed + 0.1) {
        status = '${remaining.formatShort()} remaining · ahead of pace';
        color = finance.warning;
      } else {
        status = '${remaining.formatShort()} remaining · on pace';
        color = finance.success;
      }
    }

    return MetricCard(
      eyebrow: 'Spent this month',
      figure: spent.formatShort(),
      figureSuffix: allocated.isPositive ? 'of ${allocated.formatShort()}' : null,
      status: status,
      statusColor: color,
      child: totalAllocated.isPositive
          ? SplitBar([
              for (var i = 0; i < list.length; i++)
                if (list[i].budget.allocated.isPositive)
                  BarSegment(
                    list[i].budget.bucket,
                    list[i].budget.allocated.amount.toDouble(),
                    _toneForBucket(context, list[i].budget.bucket, i).fg,
                    amountLabel: list[i].budget.allocated.formatShort(),
                  ),
            ])
          : null,
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({
    required this.b,
    required this.tone,
    required this.categories,
    required this.canWrite,
  });
  final BudgetWithSpend b;
  final Tone tone;
  final List<({String name, double total})> categories;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final allocated = b.budget.allocated;
    final hasAllocation = allocated.isPositive;

    final barColor = b.isOverBudget
        ? finance.expense
        : (b.utilization >= 85 ? finance.warning : tone.fg);

    final Widget? pill;
    if (!hasAllocation) {
      pill = null;
    } else if (b.isNonExpense) {
      pill = TonePill('Set aside', Tones.mint(context));
    } else if (b.isOverBudget) {
      pill = TonePill('Over', Tones.coral(context));
    } else if (b.utilization >= 85) {
      pill = TonePill('Near limit', Tones.butter(context));
    } else {
      pill = TonePill('On track', Tones.mint(context));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: canWrite ? () => openAllocationSheet(context, b) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ToneTile(icon: _iconForBucket(b.budget.bucket), tone: tone, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.budget.bucket,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        hasAllocation
                            ? '${b.spent.formatShort()} / ${allocated.formatShort()}'
                            : (canWrite ? 'Set a budget' : 'No budget'),
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
                ?pill,
                if (!hasAllocation && canWrite)
                  Icon(Icons.add_circle_outline_rounded, color: palette.faint),
              ],
            ),
            if (hasAllocation) ...[
              const SizedBox(height: AppSpacing.md),
              SlimBar(value: b.utilization / 100, color: barColor),
              const SizedBox(height: AppSpacing.sm),
              Text(
                b.isNonExpense
                    ? 'Money set aside — no tracked spend'
                    : b.isOverBudget
                    ? '${b.remaining.abs.formatShort()} over'
                    : '${b.remaining.formatShort()} left',
                style: AppTypography.label.copyWith(
                  color: b.isOverBudget ? finance.expense : palette.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Divider(height: 1, color: palette.line),
                const SizedBox(height: AppSpacing.md),
                for (final c in categories)
                  _CategoryRow(
                    name: c.name,
                    amount: c.total,
                    share: b.spent.amount.toDouble() <= 0
                        ? 0
                        : c.total / b.spent.amount.toDouble(),
                    color: tone.fg,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.name,
    required this.amount,
    required this.share,
    required this.color,
  });
  final String name;
  final double amount;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(color: palette.ink),
                ),
              ),
              Text(
                Money(Decimal.parse(amount.toStringAsFixed(2))).formatShort(),
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SlimBar(value: share, color: color, height: 4),
        ],
      ),
    );
  }
}
