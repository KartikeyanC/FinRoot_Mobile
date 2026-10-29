import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money_format.dart';
import '../../../../core/providers/providers.dart';
import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../../navigation/quick_add_entry.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../debts/debts.dart';
import '../../../goals/application/goals_providers.dart';
import '../../../investments/application/investments_providers.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../profile/profile_providers.dart';
import '../../../recurring/application/recurring_providers.dart';
import '../../../recurring/domain/recurring_item.dart';
import '../../../summary/application/summary_providers.dart';
import '../../../summary/domain/workspace_summary.dart';
import '../../domain/wealth_figures.dart';

/// The web dashboard's default "Wealth" layout (`DashboardWealth.tsx`), card
/// for card, stacked into one column for the phone: greeting + Add
/// transaction, net-worth hero, financial health, cash flow, net spending,
/// upcoming bills, investment performance, and the metrics strip.
class WealthDashboard extends ConsumerWidget {
  const WealthDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(workspaceSummaryProvider).value ?? WorkspaceSummary.empty();
    final cash = ref.watch(totalBalanceProvider).amount.toDouble();
    final portfolio = ref.watch(portfolioSummaryProvider);
    final investments = ref.watch(investmentsProvider).value ?? const [];
    final debts = ref.watch(debtsProvider).value ?? const <Debt>[];
    final goals = ref.watch(goalsProvider).value ?? const [];
    final bills = ref.watch(recurringItemsProvider).value ?? const <RecurringItem>[];
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
    final expenseSeries = [for (final p in series) p.expense.amount.toDouble()];
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
        const _Greeting(),
        gap,
        if (can(FeatureMenu.netWorth))
          _NetWorthHero(
            netWorth: assets - liabilities,
            income: income,
            expense: expense,
            incomeSeries: incomeSeries,
            expenseSeries: expenseSeries,
          )
        else
          const _Panel(child: Center(child: Text('Net worth is not available on your plan.'))),
        gap,
        _HealthPanel(health),
        gap,
        _CashFlowPanel(
          inflows: summary.categoryIncome.take(4).toList(),
          outflows: summary.categorySpend.take(4).toList(),
        ),
        if (can(FeatureMenu.expenses)) ...[gap, _SpendingDonut(summary.categorySpend)],
        if (can(FeatureMenu.reminders)) ...[gap, _UpcomingBills(upcoming.take(4).toList())],
        if (can(FeatureMenu.investments)) ...[
          gap,
          _InvestmentPanel(
            current: invCurrent,
            invested: invInvested,
            series: cumulativeHoldings([for (final r in investments) r.current.amount.toDouble()]),
          ),
        ],
        if (can(FeatureMenu.netWorth)) ...[
          gap,
          _MetricsGrid([
            ('Total assets', MoneyFormat.compact(assets), Icons.trending_up),
            ('Liabilities', MoneyFormat.compact(liabilities), Icons.trending_down),
            ('Monthly savings', MoneyFormat.compact(savings), Icons.account_balance_wallet_outlined),
            if (can(FeatureMenu.budget)) ('Savings rate', '$rate%', Icons.show_chart),
          ]),
        ],
      ],
    );
  }
}

// ─────────────────────────── shared pieces ───────────────────────────

/// The web's `glass-card p-5`.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.title, this.icon});
  final Widget child;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: AppTypography.sectionLabel.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 24, color: muted.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.sm),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 14)),
        ],
      ),
    );
  }
}

TextStyle _num(BuildContext context, double size, {Color? color}) => AppTypography.money.copyWith(
      fontSize: size,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );

// ─────────────────────────── greeting ───────────────────────────

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final display = ref.watch(profileProvider).value?.displayName?.trim();
    final email = ref.watch(currentUserProvider)?.email;
    final name = (display != null && display.isNotEmpty)
        ? display.split(RegExp(r'\s+')).first
        : (email?.split('@').first ?? 'there');
    final h = DateTime.now().hour;
    final hello = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.auto_awesome, size: 14, color: finance.brandText),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'DASHBOARD',
                  style: AppTypography.sectionLabel.copyWith(
                    fontSize: 12,
                    letterSpacing: 1.6,
                    color: finance.brandText,
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Text('$hello, $name', style: tt.headlineSmall),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton.icon(
          onPressed: () => openQuickAdd(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          icon: const Icon(Icons.north_east, size: 16),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

// ─────────────────────────── net worth hero ───────────────────────────

class _NetWorthHero extends StatelessWidget {
  const _NetWorthHero({
    required this.netWorth,
    required this.income,
    required this.expense,
    required this.incomeSeries,
    required this.expenseSeries,
  });

  final double netWorth;
  final double income;
  final double expense;
  final List<double> incomeSeries;
  final List<double> expenseSeries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NET WORTH',
              style: TextStyle(fontSize: 12, letterSpacing: 1.0, color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          // The web's `text-gradient-primary`: brand green → chart cyan.
          ShaderMask(
            shaderCallback: (r) => LinearGradient(colors: [finance.brandText, AppColors.gradientEnd])
                .createShader(r),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                MoneyFormat.compact(netWorth),
                style: _num(context, 36, color: Colors.white).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: _MiniStat('Income', income, incomeSeries, positive: true)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _MiniStat('Expenses', expense, expenseSeries, positive: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.series, {required this.positive});
  final String label;
  final double value;
  final List<double> series;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final accent = positive ? finance.income : finance.expense;
    final mom = monthOnMonth(series);
    final good = mom == null ? null : (positive ? mom >= 0 : mom <= 0);
    final max = series.isEmpty ? 1.0 : math.max(1.0, series.reduce(math.max));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.6)),
        color: scheme.surface.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))),
              if (mom != null)
                Text(
                  '${mom >= 0 ? '+' : ''}${mom.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: good! ? finance.income : finance.expense,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(MoneyFormat.compact(value), style: _num(context, 18)),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < series.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: FractionallySizedBox(
                      heightFactor: math.max(0.08, series[i] / max),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i == series.length - 1 ? accent : accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── financial health ───────────────────────────

class _HealthPanel extends StatelessWidget {
  const _HealthPanel(this.health);
  final HealthScore health;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    return _Panel(
      title: 'Financial health',
      icon: Icons.monitor_heart_outlined,
      child: Row(
        children: [
          SizedBox.square(
            dimension: 104,
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
                      backgroundColor: scheme.outlineVariant,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${health.score}%', style: _num(context, 22)),
                    Text(health.verdict, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
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
                      children: [
                        Icon(
                          c.ok ? Icons.check_circle : Icons.circle_outlined,
                          size: 15,
                          color: c.ok ? finance.income : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            c.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.ok ? scheme.onSurface : scheme.onSurfaceVariant,
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
  const _CashFlowPanel({required this.inflows, required this.outflows});
  final List<CategorySpendPoint> inflows;
  final List<CategorySpendPoint> outflows;

  @override
  Widget build(BuildContext context) {
    final values = [...inflows, ...outflows].map((c) => c.amount.amount.toDouble());
    final max = values.isEmpty ? 1.0 : math.max(1.0, values.reduce(math.max));
    return _Panel(
      title: 'Cash flow',
      icon: Icons.show_chart,
      child: inflows.isEmpty && outflows.isEmpty
          ? const _EmptyRow(Icons.show_chart, 'Log income and expenses to see your flow.')
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
    final scheme = Theme.of(context).colorScheme;
    final color = income ? context.finance.income : context.finance.expense;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 11, letterSpacing: 1.0, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(height: AppSpacing.sm),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(r.category,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 14,
                      color: scheme.outlineVariant,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0.04, r.amount.amount.toDouble() / max),
                        child: Container(
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 72,
                  child: Text(MoneyFormat.compact(r.amount.amount.toDouble()),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _num(context, 12)),
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
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final deck = dark ? AppColors.chartDark : AppColors.chartLight;
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

    return _Panel(
      title: 'Net spending',
      icon: Icons.pie_chart_outline,
      child: items.isEmpty
          ? const _EmptyRow(Icons.pie_chart_outline, 'No expenses logged this month yet.')
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
                          gapColor: scheme.surface,
                        ),
                      ),
                      SizedBox(
                        width: 58,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: sel == null
                              ? [
                                  Text('SPENT',
                                      style: TextStyle(
                                          fontSize: 10, letterSpacing: 1, color: scheme.onSurfaceVariant)),
                                  FittedBox(child: Text(MoneyFormat.compact(total), style: _num(context, 13))),
                                ]
                              : [
                                  Text(sel.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                                  FittedBox(child: Text(MoneyFormat.compact(sel.value), style: _num(context, 13))),
                                  Text('${sel.pct}%', style: TextStyle(fontSize: 11, color: sel.color)),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < math.min(5, items.length); i++)
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => setState(() => _active = _active == i ? null : i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: _active == i ? scheme.primary.withValues(alpha: 0.1) : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(color: items[i].color, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(items[i].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _active == i ? scheme.onSurface : scheme.onSurfaceVariant,
                                      )),
                                ),
                                Text('${items[i].pct}%',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurface)),
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
  _DonutPainter(this.slices, {required this.active, required this.gapColor});
  final List<(double, Color)> slices;
  final int? active;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, x) => s + x.$1);
    if (total <= 0) return;
    final center = size.center(Offset.zero);
    const outer = 50.0 * 128 / 100;
    const inner = 32.0 * 128 / 100;
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
    final scheme = Theme.of(context).colorScheme;
    return _Panel(
      title: 'Upcoming bills',
      icon: Icons.event_outlined,
      child: items.isEmpty
          ? const _EmptyRow(Icons.event_outlined, 'No upcoming bills. Add recurring expenses to track them.')
          : Column(
              children: [
                for (final b in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.receipt_long_outlined, size: 16, color: context.finance.brandText),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(DateFormat('d MMM').format(b.nextDueDate),
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text(
                          '−${MoneyFormat.money(b.amount.amount.toDouble(), currency: b.amount.currency)}',
                          style: _num(context, 14, color: context.finance.expense)
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
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
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final delta = current - invested;
    final pct = invested > 0 ? delta / invested * 100 : 0.0;
    final up = delta >= 0;
    return _Panel(
      title: 'Investment performance',
      icon: Icons.stacked_line_chart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(MoneyFormat.compact(current), style: _num(context, 24)),
                ),
              ),
              if (invested > 0) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(up ? Icons.north_east : Icons.south_east,
                    size: 14, color: up ? finance.income : finance.expense),
                Text('${up ? '+' : ''}${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500, color: up ? finance.income : finance.expense)),
              ],
            ],
          ),
          if (series.isEmpty)
            const _EmptyRow(Icons.stacked_line_chart, 'Add holdings on the Investments page to track performance.')
          else ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(painter: _AreaPainter(series, const Color(0xFF2EB88A))),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cumulative value across ${series.length} holding${series.length == 1 ? '' : 's'}.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// The web's monotone area chart (stroke hsl(160,60%,45%), 35% → 0 fill).
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
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_AreaPainter old) => old.values != values;
}

// ─────────────────────────── metrics strip ───────────────────────────

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid(this.metrics);
  final List<(String, String, IconData)> metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile((String, String, IconData) m) => Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(m.$1.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant)),
                  ),
                  Icon(m.$3, size: 16, color: scheme.onSurfaceVariant),
                ]),
                const SizedBox(height: AppSpacing.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(m.$2, style: _num(context, 22).copyWith(letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
        );
    final rows = <Widget>[];
    for (var i = 0; i < metrics.length; i += 2) {
      rows.add(Row(
        children: [
          Expanded(child: tile(metrics[i])),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: i + 1 < metrics.length ? tile(metrics[i + 1]) : const SizedBox()),
        ],
      ));
      if (i + 2 < metrics.length) rows.add(const SizedBox(height: AppSpacing.md));
    }
    return Column(children: rows);
  }
}
