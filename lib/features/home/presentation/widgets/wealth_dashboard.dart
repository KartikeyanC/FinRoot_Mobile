import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money_format.dart';
import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../../navigation/quick_add_entry.dart';
import '../../../insights/domain/insight.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../privacy/income_privacy.dart';
import '../../../recurring/domain/recurring_item.dart';
import '../../../summary/domain/workspace_summary.dart';
import '../../application/home_wealth.dart';
import '../../domain/home_layout.dart';
import '../../domain/wealth_figures.dart';
import 'home_parts.dart';

/// One of the web dashboard's "Wealth" cards (`DashboardWealth.tsx`), rebuilt
/// for the phone in NineFlow's structure: the heads-up pill, the net-worth
/// headline card, a strip of the month's numbers, cash flow, financial health,
/// net spending, upcoming bills and investment performance. Home draws them in
/// the person's order ([HomeLayout]); the figures come from [homeWealthProvider].
///
/// Draws nothing for a block that is not a wealth card, or one with nothing to
/// show — check [wealthBlockShows] first so Home spaces only what it draws.
class WealthBlock extends ConsumerWidget {
  const WealthBlock(this.block, {super.key});

  final HomeBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(homeWealthProvider);
    bool can(FeatureMenu m) =>
        ref.watch(menuStatusProvider(m)) != MenuStatus.locked;

    switch (block) {
      case HomeBlock.nudge:
        return _Nudge(
          nextBill: w.nudgeBill(DateTime.now()),
          insight: w.topInsight,
        );
      case HomeBlock.netWorth:
        if (!can(FeatureMenu.netWorth)) {
          return const HomeSection(
            title: 'Net worth',
            child: HomeEmpty(
              icon: Icons.lock_outline_rounded,
              title: 'Not available',
              message: 'Net worth is not available on your plan.',
            ),
          );
        }
        return _NetWorthCard(
          netWorth: w.netWorth,
          assets: w.assets,
          liabilities: w.liabilities,
          savings: w.savings,
          maskSavings: ref.watch(incomePrivacyProvider).masked,
          hasActivity: w.hasActivity,
          hasAccounts: w.hasAccounts,
          canBudget: can(FeatureMenu.budget),
        );
      case HomeBlock.monthStats:
        return _MonthStats([
          Stat(
            incomeText(ref, MoneyFormat.short(w.income)),
            'Income',
            color: context.finance.income,
          ),
          Stat(
            MoneyFormat.short(w.expense),
            'Spent',
            color: context.finance.expense,
          ),
          // Saved = income − spent, so it is hidden with income.
          Stat(
            incomeText(ref, MoneyFormat.short(w.savings)),
            'Saved',
            color: w.savings >= 0
                ? context.finance.income
                : context.finance.expense,
          ),
          if (can(FeatureMenu.budget))
            Stat(
              incomeText(ref, '${w.rate}%').replaceAll('₹ ', ''),
              'Savings rate',
            )
          else
            Stat('${w.summary.transactionCount}', 'Entries'),
        ]);
      case HomeBlock.cashFlow:
        return _CashFlowPanel(
          inflows: w.summary.categoryIncome.take(4).toList(),
          outflows: w.summary.categorySpend.take(4).toList(),
          incomeMom: w.incomeMom,
          maskIncome: ref.watch(incomePrivacyProvider).masked,
        );
      case HomeBlock.health:
        return _HealthPanel(w.health);
      case HomeBlock.spending:
        if (!can(FeatureMenu.expenses)) return const SizedBox.shrink();
        return _SpendingDonut(w.summary.categorySpend);
      case HomeBlock.bills:
        if (!can(FeatureMenu.reminders)) return const SizedBox.shrink();
        return _UpcomingBills(w.upcoming.take(4).toList());
      case HomeBlock.investments:
        if (!can(FeatureMenu.investments)) return const SizedBox.shrink();
        return _InvestmentPanel(
          current: w.investedCurrent,
          invested: w.invested,
          series: w.investmentSeries,
        );
      case HomeBlock.recent:
      case HomeBlock.trackers:
      case HomeBlock.insights:
        return const SizedBox.shrink();
    }
  }
}

/// Whether [WealthBlock] draws anything for [block] right now: false for the
/// phone-only blocks, for a card whose menu is locked on the plan (net worth
/// shows a "not available" card instead), and for an empty heads-up.
bool wealthBlockShows(WidgetRef ref, HomeBlock block) {
  bool can(FeatureMenu m) =>
      ref.watch(menuStatusProvider(m)) != MenuStatus.locked;
  return switch (block) {
    HomeBlock.nudge => () {
      final w = ref.watch(homeWealthProvider);
      return w.nudgeBill(DateTime.now()) != null || w.topInsight != null;
    }(),
    HomeBlock.netWorth ||
    HomeBlock.monthStats ||
    HomeBlock.cashFlow ||
    HomeBlock.health => true,
    HomeBlock.spending => can(FeatureMenu.expenses),
    HomeBlock.bills => can(FeatureMenu.reminders),
    HomeBlock.investments => can(FeatureMenu.investments),
    HomeBlock.recent || HomeBlock.trackers || HomeBlock.insights => false,
  };
}

// ─────────────────────────── month stats ───────────────────────────

/// The month's figures as one [StatStrip] when all four fit at full size,
/// else a 2×2 card so a narrow phone or large text never shrinks the money
/// figures or cuts a label short.
class _MonthStats extends StatelessWidget {
  const _MonthStats(this.stats);

  final List<Stat> stats;

  static final _valueStyle = AppTypography.display.copyWith(
    fontSize: 24,
    height: 30 / 24,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static final _labelStyle = AppTypography.label.copyWith(
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double width(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    // Each column needs its widest line plus the strip's 6dp side padding.
    final need = stats
        .map(
          (s) =>
              math.max(
                width(s.value, _valueStyle),
                width(s.label, _labelStyle),
              ) +
              12,
        )
        .reduce(math.max);
    return LayoutBuilder(
      builder: (context, c) {
        // StatStrip: 8dp card padding each side and a 1dp hairline per gap.
        final column =
            (c.maxWidth - AppSpacing.sm * 2 - (stats.length - 1)) /
            stats.length;
        if (stats.length < 4 || need <= column) return StatStrip(stats);
        return _StatGrid(stats);
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid(this.stats);

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget cell(Stat s) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                s.value,
                style: _MonthStats._valueStyle.copyWith(
                  color: s.color ?? palette.ink,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _MonthStats._labelStyle.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
    final rows = [
      for (var i = 0; i < stats.length; i += 2)
        IntrinsicHeight(
          child: Row(
            children: [
              cell(stats[i]),
              VerticalDivider(width: 1, color: palette.line),
              if (i + 1 < stats.length) cell(stats[i + 1]) else const Spacer(),
            ],
          ),
        ),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.sm,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: AppSpacing.xxl, color: palette.line),
            rows[i],
          ],
        ],
      ),
    );
  }
}

TextStyle _num(BuildContext context, double size, {Color? color}) =>
    AppTypography.bodyStrong.copyWith(
      fontSize: size,
      height: 1.2,
      color: color ?? context.palette.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// ─────────────────────────── nudge banner ───────────────────────────

/// The single most useful nudge: a bill due within a week, else the top
/// insight. Not dismissible (the app has no dismiss state for either).
class _Nudge extends StatelessWidget {
  const _Nudge({required this.nextBill, required this.insight});

  /// The next bill, already known to be due within a week.
  final RecurringItem? nextBill;
  final Insight? insight;

  @override
  Widget build(BuildContext context) {
    final bill = nextBill;
    if (bill != null) {
      final days = bill.daysUntilDue(now: DateTime.now());
      final when = switch (days) {
        < 0 => '${-days}d overdue',
        0 => 'due today',
        1 => 'due tomorrow',
        _ => 'due in ${days}d',
      };
      return InfoPill(
        icon: Icons.event_rounded,
        text: '${bill.name} $when',
        detail: MoneyFormat.compact(
          bill.amount.amount.toDouble(),
          currency: bill.amount.currency,
        ),
        onTap: () => context.push('/recurring'),
      );
    }
    final i = insight;
    if (i != null) {
      final route = i.route;
      return InfoPill(
        icon: i.icon,
        text: i.title,
        onTap: route == null ? null : () => context.push(route),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────── net worth headline ───────────────────────────

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.netWorth,
    required this.assets,
    required this.liabilities,
    required this.savings,
    this.maskSavings = false,
    required this.hasActivity,
    required this.hasAccounts,
    required this.canBudget,
  });

  final double netWorth;
  final double assets;
  final double liabilities;
  final double savings;

  /// Income is hidden: savings would give it away.
  final bool maskSavings;
  final bool hasActivity;
  final bool hasAccounts;
  final bool canBudget;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final palette = context.palette;

    final String status;
    final Color statusColor;
    if (!hasActivity) {
      status = 'Nothing recorded this month yet';
      statusColor = palette.muted;
    } else if (maskSavings) {
      status = 'This month: $kIncomeMask (income hidden)';
      statusColor = palette.muted;
    } else if (savings >= 0) {
      status = '${MoneyFormat.compact(savings)} saved this month';
      statusColor = finance.income;
    } else {
      status = '${MoneyFormat.compact(-savings)} overspent this month';
      statusColor = finance.expense;
    }

    final VoidCallback onAction;
    final String actionLabel;
    if (!hasAccounts) {
      actionLabel = 'Add your accounts';
      onAction = () => context.push('/accounts');
    } else if (hasActivity && savings < 0 && canBudget) {
      actionLabel = 'Review your budget';
      onAction = () => context.push('/budget');
    } else {
      actionLabel = 'Add a transaction';
      onAction = () => openQuickAdd(context);
    }

    return MetricCard(
      eyebrow: 'Net worth',
      figure: MoneyFormat.money(netWorth),
      status: status,
      statusColor: statusColor,
      action: PillButton(
        label: actionLabel,
        trailingArrow: true,
        onPressed: onAction,
      ),
      child: assets > 0 || liabilities > 0
          ? SegmentedBar([
              BarSegment(
                'Assets',
                assets,
                palette.accent,
                amountLabel: MoneyFormat.short(assets),
              ),
              BarSegment(
                'Liabilities',
                liabilities,
                finance.expense,
                amountLabel: MoneyFormat.short(liabilities),
              ),
            ])
          : null,
    );
  }
}

// ─────────────────────────── financial health ───────────────────────────

class _HealthPanel extends StatelessWidget {
  const _HealthPanel(this.health);
  final HealthScore health;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final tone = health.score >= 75
        ? HomeTone.mint
        : health.score >= 50
        ? HomeTone.butter
        : HomeTone.coral;
    return HomeSection(
      title: 'Financial health',
      trailing: TonePill(health.verdict, tone),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: health.score / 100),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (_, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 9,
                      strokeCap: StrokeCap.round,
                      backgroundColor: palette.line,
                      color: palette.accent,
                    ),
                  ),
                ),
                Text(
                  '${health.score}%',
                  style: AppTypography.display.copyWith(
                    fontSize: 22,
                    height: 1.2,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final c in health.checks)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          c.ok
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 16,
                          color: c.ok ? finance.income : palette.faint,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c.label,
                            style: AppTypography.label.copyWith(
                              fontWeight: FontWeight.w500,
                              color: c.ok ? palette.ink : palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── cash flow ───────────────────────────

class _CashFlowPanel extends StatelessWidget {
  const _CashFlowPanel({
    required this.inflows,
    required this.outflows,
    required this.incomeMom,
    this.maskIncome = false,
  });
  final List<CategorySpendPoint> inflows;
  final List<CategorySpendPoint> outflows;
  final bool maskIncome;
  final double? incomeMom;

  @override
  Widget build(BuildContext context) {
    final values = [
      ...inflows,
      ...outflows,
    ].map((c) => c.amount.amount.toDouble());
    final max = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    final mom = incomeMom;
    return HomeSection(
      title: 'Cash flow',
      trailing: mom == null
          ? null
          : TonePill(
              '${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(1)}% income',
              mom >= 0 ? HomeTone.mint : HomeTone.coral,
              dot: false,
            ),
      child: inflows.isEmpty && outflows.isEmpty
          ? const HomeEmpty(
              icon: Icons.show_chart_rounded,
              title: 'No cash flow yet',
              message: 'Log income and expenses to see your flow.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (inflows.isNotEmpty)
                  _FlowGroup(
                    'In',
                    inflows,
                    max,
                    income: true,
                    masked: maskIncome,
                  ),
                if (inflows.isNotEmpty && outflows.isNotEmpty)
                  const SizedBox(height: AppSpacing.lg),
                if (outflows.isNotEmpty)
                  _FlowGroup('Out', outflows, max, income: false),
              ],
            ),
    );
  }
}

class _FlowGroup extends StatelessWidget {
  const _FlowGroup(
    this.label,
    this.rows,
    this.max, {
    required this.income,
    this.masked = false,
  });

  /// Show amounts as ₹ •••• (hidden income).
  final bool masked;
  final String label;
  final List<CategorySpendPoint> rows;
  final double max;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = income ? context.finance.income : context.finance.expense;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label, color: color),
        const SizedBox(height: AppSpacing.sm),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      masked
                          ? kIncomeMask
                          : MoneyFormat.compact(r.amount.amount.toDouble()),
                      maxLines: 1,
                      style: _num(context, 14),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: AppRadius.chip,
                  child: Container(
                    height: 8,
                    color: palette.line,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      heightFactor: 1,
                      widthFactor: math
                          .max(0.04, r.amount.amount.toDouble() / max)
                          .clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: AppRadius.chip,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────── net spending donut ───────────────────────────

class _SpendingDonut extends StatefulWidget {
  const _SpendingDonut(this.data);
  final List<CategorySpendPoint> data;

  @override
  State<_SpendingDonut> createState() => _SpendingDonutState();
}

class _SpendingDonutState extends State<_SpendingDonut> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final deck = palette.isDark ? AppColors.chartDark : AppColors.chartLight;
    final total = widget.data.fold<double>(
      0,
      (s, d) => s + d.amount.amount.toDouble(),
    );
    final items = [
      for (var i = 0; i < widget.data.length; i++)
        (
          name: widget.data[i].category,
          value: widget.data[i].amount.amount.toDouble(),
          color: deck[i % deck.length],
          pct: total > 0
              ? (widget.data[i].amount.amount.toDouble() / total * 100).round()
              : 0,
        ),
    ];
    final sel = _active == null ? null : items[_active!];

    return HomeSection(
      title: 'Net spending',
      trailing: items.isEmpty
          ? null
          : TonePill(MoneyFormat.short(total), HomeTone.coral, dot: false),
      child: items.isEmpty
          ? const HomeEmpty(
              icon: Icons.pie_chart_outline_rounded,
              title: 'No spending yet',
              message: 'No expenses logged this month yet.',
            )
          : Row(
              children: [
                SizedBox.square(
                  dimension: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(128),
                        painter: _DonutPainter([
                          for (final it in items) (it.value, it.color),
                        ], active: _active),
                      ),
                      SizedBox(
                        width: 62,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: sel == null
                              ? [
                                  Text(
                                    'Spent',
                                    style: AppTypography.caption.copyWith(
                                      color: palette.muted,
                                    ),
                                  ),
                                  FittedBox(
                                    child: Text(
                                      MoneyFormat.compact(total),
                                      style: _num(context, 14),
                                    ),
                                  ),
                                ]
                              : [
                                  Text(
                                    sel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: palette.muted,
                                    ),
                                  ),
                                  FittedBox(
                                    child: Text(
                                      MoneyFormat.compact(sel.value),
                                      style: _num(context, 14),
                                    ),
                                  ),
                                  Text(
                                    '${sel.pct}%',
                                    style: AppTypography.caption.copyWith(
                                      color: palette.accentText,
                                    ),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < math.min(5, items.length); i++)
                        InkWell(
                          borderRadius: AppRadius.chip,
                          onTap: () =>
                              setState(() => _active = _active == i ? null : i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.chip,
                              color: _active == i ? palette.tint : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: items[i].color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    items[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: _active == i
                                          ? palette.ink
                                          : palette.muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${items[i].pct}%',
                                  style: AppTypography.label.copyWith(
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, {required this.active});
  final List<(double, Color)> slices;
  final int? active;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, x) => s + x.$1);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    const outer = 50.0 * 128 / 100;
    const inner = 34.0 * 128 / 100;
    const stroke = outer - inner;
    const pad = 3 * math.pi / 180; // web paddingAngle 3°
    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = slices[i].$1 / total * 2 * math.pi;
      final grow = active == i ? 4.0 : 0.0;
      final r = (outer + inner) / 2 + grow / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke + grow
        ..color = slices[i].$2.withValues(
          alpha: active == null || active == i ? 1 : 0.5,
        );
      final s = slices.length > 1 ? math.max(0.0, sweep - pad) : sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start + pad / 2,
        s,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.active != active || old.slices != slices;
}

// ─────────────────────────── upcoming bills ───────────────────────────

class _UpcomingBills extends StatelessWidget {
  const _UpcomingBills(this.items);
  final List<RecurringItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final now = DateTime.now();
    return HomeSection(
      title: 'Upcoming bills',
      trailing: HomeSeeAll(
        label: 'All bills',
        onPressed: () => context.push('/recurring'),
      ),
      child: items.isEmpty
          ? const HomeEmpty(
              icon: Icons.event_outlined,
              title: 'No upcoming bills',
              message: 'Add recurring expenses to track them.',
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: HomeDivider(),
                    ),
                  Row(
                    children: [
                      const IconTile(icon: Icons.receipt_long_outlined),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyStrong.copyWith(
                                color: palette.ink,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('d MMM').format(items[i].nextDueDate),
                              style: AppTypography.label.copyWith(
                                color: items[i].daysUntilDue(now: now) <= 2
                                    ? context.finance.expense
                                    : palette.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '-${MoneyFormat.money(items[i].amount.amount.toDouble(), currency: items[i].amount.currency)}',
                        style: _num(
                          context,
                          15,
                          color: context.finance.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

// ─────────────────────────── investment performance ───────────────────────────

class _InvestmentPanel extends StatelessWidget {
  const _InvestmentPanel({
    required this.current,
    required this.invested,
    required this.series,
  });
  final double current;
  final double invested;
  final List<double> series;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final delta = current - invested;
    final pct = invested > 0 ? delta / invested * 100 : 0.0;
    final up = delta >= 0;
    return HomeSection(
      title: 'Investments',
      trailing: invested > 0
          ? TonePill(
              '${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
              up ? HomeTone.mint : HomeTone.coral,
              dot: false,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              MoneyFormat.money(current),
              style: AppTypography.display.copyWith(
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (series.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const HomeEmpty(
              icon: Icons.stacked_line_chart_rounded,
              title: 'No holdings yet',
              message:
                  'Add holdings on the Investments page to track performance.',
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(painter: _AreaPainter(series, palette.accent)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cumulative value across ${series.length} holding${series.length == 1 ? '' : 's'}.',
              style: AppTypography.label.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The web's monotone area chart (35% → 0 fill).
class _AreaPainter extends CustomPainter {
  _AreaPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final max = values.reduce(math.max);
    const pad = 6.0;
    final w = size.width - pad * 2;
    final h = size.height - pad;
    final pts = [
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + (values.length == 1 ? w / 2 : w * i / (values.length - 1)),
          pad + h - (max > 0 ? values[i] / max * h : 0),
        ),
    ];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      line.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_AreaPainter old) =>
      old.values != values || old.color != color;
}
