import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money_format.dart';
import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../../navigation/quick_add_entry.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../debts/debts.dart';
import '../../../goals/application/goals_providers.dart';
import '../../../insights/application/insights_providers.dart';
import '../../../insights/domain/insight.dart';
import '../../../investments/application/investments_providers.dart';
import '../../../investments/domain/live_price.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../recurring/application/recurring_providers.dart';
import '../../../recurring/domain/recurring_item.dart';
import '../../../summary/application/summary_providers.dart';
import '../../../summary/domain/workspace_summary.dart';
import '../../domain/wealth_figures.dart';
import 'home_parts.dart';

/// The web dashboard's default "Wealth" layout (`DashboardWealth.tsx`), card
/// for card, rebuilt for the phone in NineFlow's structure: a nudge pill, the
/// net-worth headline card, a strip of the month's numbers, then cash flow,
/// financial health, net spending, upcoming bills and investment performance.
class WealthDashboard extends ConsumerWidget {
  const WealthDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(workspaceSummaryProvider).value ?? WorkspaceSummary.empty();
    final cash = ref.watch(totalBalanceProvider).amount.toDouble();
    final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
    final portfolio = ref.watch(portfolioSummaryProvider);
    final investments = ref.watch(investmentsProvider).value ?? const [];
    final livePrices = ref.watch(holdingPricesProvider).value ?? const <String, double>{};
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final goals = ref.watch(goalsProvider).value ?? const [];
    final bills = ref.watch(recurringItemsProvider).value ?? const <RecurringItem>[];
    final insights = ref.watch(homeInsightsProvider);
    bool can(FeatureMenu m) => ref.watch(menuStatusProvider(m)) != MenuStatus.locked;

    final income = summary.monthIncome.amount.toDouble();
    final expense = summary.monthExpense.amount.toDouble();
    final savings = income - expense;
    final rate = savingsRate(income, expense);
    final invCurrent = portfolio.current.amount.toDouble();
    final invInvested = portfolio.invested.amount.toDouble();
    final assets = cash + invCurrent;
    final liabilities = debts.fold<double>(0, (s, d) => s + math.max(0, d.remaining));
    final series = summary.monthlySeries.length > 6
        ? summary.monthlySeries.sublist(summary.monthlySeries.length - 6)
        : summary.monthlySeries;
    final incomeSeries = [for (final p in series) p.income.amount.toDouble()];
    final health = healthScore(
      savings: savings,
      savingsRate: rate,
      goalProgress: [
        for (final g in goals)
          if (g.target.amount.toDouble() > 0)
            (g.current.amount.toDouble() / g.target.amount.toDouble()).clamp(0, 1).toDouble(),
      ],
      assets: assets,
      liabilities: liabilities,
    );
    final upcoming = [
      for (final b in bills)
        if (b.isActive && b.type == RecurringType.expense) b,
    ]..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    const gap = SizedBox(height: AppSpacing.lg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Nudge(
          nextBill: upcoming.isEmpty ? null : upcoming.first,
          insight: insights.isEmpty ? null : insights.first,
        ),
        if (can(FeatureMenu.netWorth))
          _NetWorthCard(
            netWorth: assets - liabilities,
            assets: assets,
            liabilities: liabilities,
            savings: savings,
            hasActivity: income > 0 || expense > 0,
            hasAccounts: accounts.isNotEmpty,
            canBudget: can(FeatureMenu.budget),
          )
        else
          const HomeSection(
            title: 'Net worth',
            child: HomeEmpty(
              icon: Icons.lock_outline_rounded,
              title: 'Not available',
              message: 'Net worth is not available on your plan.',
            ),
          ),
        gap,
        StatStrip([
          Stat(MoneyFormat.short(income), 'Income', color: context.finance.income),
          Stat(MoneyFormat.short(expense), 'Spent', color: context.finance.expense),
          Stat(
            MoneyFormat.short(savings),
            'Saved',
            color: savings >= 0 ? context.finance.income : context.finance.expense,
          ),
          if (can(FeatureMenu.budget))
            Stat('$rate%', 'Savings rate')
          else
            Stat('${summary.transactionCount}', 'Entries'),
        ]),
        gap,
        _CashFlowPanel(
          inflows: summary.categoryIncome.take(4).toList(),
          outflows: summary.categorySpend.take(4).toList(),
          incomeMom: monthOnMonth(incomeSeries),
        ),
        gap,
        _HealthPanel(health),
        if (can(FeatureMenu.expenses)) ...[gap, _SpendingDonut(summary.categorySpend)],
        if (can(FeatureMenu.reminders)) ...[gap, _UpcomingBills(upcoming.take(4).toList())],
        if (can(FeatureMenu.investments)) ...[
          gap,
          _InvestmentPanel(
            current: invCurrent,
            invested: invInvested,
            series: cumulativeHoldings([for (final r in investments) effectiveCurrent(r, livePrices)]),
          ),
        ],
      ],
    );
  }
}

TextStyle _num(BuildContext context, double size, {Color? color}) => AppTypography.bodyStrong.copyWith(
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

  final RecurringItem? nextBill;
  final Insight? insight;

  @override
  Widget build(BuildContext context) {
    final bill = nextBill;
    if (bill != null) {
      final days = bill.daysUntilDue(now: DateTime.now());
      if (days <= 7) {
        final when = switch (days) {
          < 0 => '${-days}d overdue',
          0 => 'due today',
          1 => 'due tomorrow',
          _ => 'due in ${days}d',
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: InfoPill(
            icon: Icons.event_rounded,
            text: '${bill.name} $when',
            detail: MoneyFormat.compact(
              bill.amount.amount.toDouble(),
              currency: bill.amount.currency,
            ),
            onTap: () => context.push('/recurring'),
          ),
        );
      }
    }
    final i = insight;
    if (i != null) {
      final route = i.route;
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: InfoPill(
          icon: i.icon,
          text: i.title,
          onTap: route == null ? null : () => context.push(route),
        ),
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
    required this.hasActivity,
    required this.hasAccounts,
    required this.canBudget,
  });

  final double netWorth;
  final double assets;
  final double liabilities;
  final double savings;
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
                          c.ok ? Icons.check_circle_rounded : Icons.circle_outlined,
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
  });
  final List<CategorySpendPoint> inflows;
  final List<CategorySpendPoint> outflows;
  final double? incomeMom;

  @override
  Widget build(BuildContext context) {
    final values = [...inflows, ...outflows].map((c) => c.amount.amount.toDouble());
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
                if (inflows.isNotEmpty) _FlowGroup('In', inflows, max, income: true),
                if (inflows.isNotEmpty && outflows.isNotEmpty) const SizedBox(height: AppSpacing.lg),
                if (outflows.isNotEmpty) _FlowGroup('Out', outflows, max, income: false),
              ],
            ),
    );
  }
}

class _FlowGroup extends StatelessWidget {
  const _FlowGroup(this.label, this.rows, this.max, {required this.income});
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
                        style: AppTypography.bodyStrong.copyWith(color: palette.ink),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      MoneyFormat.compact(r.amount.amount.toDouble()),
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
                      widthFactor: math.max(0.04, r.amount.amount.toDouble() / max).clamp(0.0, 1.0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color, borderRadius: AppRadius.chip),
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
    final total = widget.data.fold<double>(0, (s, d) => s + d.amount.amount.toDouble());
    final items = [
      for (var i = 0; i < widget.data.length; i++)
        (
          name: widget.data[i].category,
          value: widget.data[i].amount.amount.toDouble(),
          color: deck[i % deck.length],
          pct: total > 0 ? (widget.data[i].amount.amount.toDouble() / total * 100).round() : 0,
        ),
    ];
    final sel = _active == null ? null : items[_active!];

    return HomeSection(
      title: 'Net spending',
      trailing: items.isEmpty ? null : TonePill(MoneyFormat.short(total), HomeTone.coral, dot: false),
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
                        painter: _DonutPainter(
                          [for (final it in items) (it.value, it.color)],
                          active: _active,
                        ),
                      ),
                      SizedBox(
                        width: 62,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: sel == null
                              ? [
                                  Text('Spent', style: AppTypography.caption.copyWith(color: palette.muted)),
                                  FittedBox(child: Text(MoneyFormat.compact(total), style: _num(context, 14))),
                                ]
                              : [
                                  Text(
                                    sel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(color: palette.muted),
                                  ),
                                  FittedBox(child: Text(MoneyFormat.compact(sel.value), style: _num(context, 14))),
                                  Text('${sel.pct}%', style: AppTypography.caption.copyWith(color: palette.accentText)),
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
                          onTap: () => setState(() => _active = _active == i ? null : i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.chip,
                              color: _active == i ? palette.tint : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: items[i].color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    items[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.label.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: _active == i ? palette.ink : palette.muted,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${items[i].pct}%',
                                  style: AppTypography.label.copyWith(color: palette.ink),
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
        ..color = slices[i].$2.withValues(alpha: active == null || active == i ? 1 : 0.5);
      final s = slices.length > 1 ? math.max(0.0, sweep - pad) : sweep;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start + pad / 2, s, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.active != active || old.slices != slices;
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
      trailing: HomeSeeAll(label: 'All bills', onPressed: () => context.push('/recurring')),
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
                              style: AppTypography.bodyStrong.copyWith(color: palette.ink, fontSize: 15),
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
                        style: _num(context, 15, color: context.finance.expense),
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
  const _InvestmentPanel({required this.current, required this.invested, required this.series});
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
              message: 'Add holdings on the Investments page to track performance.',
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
              style: AppTypography.label.copyWith(color: palette.muted, fontWeight: FontWeight.w500),
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
  bool shouldRepaint(_AreaPainter old) => old.values != values || old.color != color;
}
