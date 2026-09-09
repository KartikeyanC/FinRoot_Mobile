import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../domain/tracker_spend.dart';

/// The spend-against-budget bar. Used on the list, the detail header and Home.
/// No budget → a plain "spent so far" line, never a full or empty bar
/// (absent is not spent-in-full).
class TrackerProgress extends StatelessWidget {
  const TrackerProgress(this.t, {super.key, this.compact = false});

  final TrackerWithSpend t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final tt = Theme.of(context).textTheme;

    if (!t.hasBudget) {
      return Row(
        children: [
          Text(
            'Spent',
            style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          AmountText.money(t.spent, signed: false),
        ],
      );
    }

    final fraction = (t.utilization / 100).clamp(0.0, 1.0);
    final barColor = t.isOverBudget
        ? finance.expense
        : (t.utilization >= 85 ? finance.warning : scheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AmountText.money(t.spent, signed: false),
            Text(
              ' of ${t.tracker.budget!.formatShort()}',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            Text(
              '${t.utilization}%',
              style: tt.labelMedium?.copyWith(color: barColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: compact ? 5 : 7,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            t.isOverBudget
                ? '${t.remaining!.abs.formatShort()} over budget'
                : '${t.remaining!.formatShort()} left',
            style: tt.bodySmall?.copyWith(
              color: t.isOverBudget ? finance.expense : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
