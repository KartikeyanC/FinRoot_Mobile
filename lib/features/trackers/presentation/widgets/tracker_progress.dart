import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../domain/tracker_spend.dart';
import 'tracker_bar.dart';

/// The spend-against-budget figure and bar. Used on the list, the detail
/// header and Home. No budget -> a plain "spent so far" line, never a full or
/// empty bar (absent is not spent-in-full).
class TrackerProgress extends StatelessWidget {
  const TrackerProgress(this.t, {super.key, this.compact = false});

  final TrackerWithSpend t;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;

    if (!t.hasBudget) {
      return Row(
        children: [
          Text(
            'Spent',
            style: AppTypography.body.copyWith(color: palette.muted),
          ),
          const Spacer(),
          AmountText.money(t.spent, signed: false),
        ],
      );
    }

    final barColor = t.isOverBudget
        ? finance.expense
        : (t.utilization >= 85 ? finance.warning : palette.accent);
    final labelColor = barColor == palette.accent ? palette.accentText : barColor;
    final budget = t.tracker.budget!.amount.toDouble();
    final spent = t.spent.amount.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: t.spent.formatShort(),
                  style: AppTypography.display.copyWith(
                    fontSize: compact ? 20 : 24,
                    height: 1.2,
                    color: palette.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: '  of ${t.tracker.budget!.formatShort()}',
                      style: AppTypography.body.copyWith(color: palette.muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${t.utilization}%',
              style: AppTypography.bodyStrong.copyWith(color: labelColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: 'Spent ${t.utilization}% of budget',
          child: ExcludeSemantics(
            child: TrackerBar(fraction: spent / budget, color: barColor),
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            t.isOverBudget
                ? '${t.remaining!.abs.formatShort()} over budget'
                : '${t.remaining!.formatShort()} left',
            style: AppTypography.bodyStrong.copyWith(
              color: t.isOverBudget ? finance.expense : palette.muted,
            ),
          ),
        ],
      ],
    );
  }
}
