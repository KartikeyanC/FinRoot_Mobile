import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// "+12.4%" / "-3.0%" — the return on what was paid (same as current price
/// against the average price). An em dash when nothing was invested.
String returnPctLabel(double gain, double invested) {
  if (invested <= 0) return '—';
  final pct = gain / invested * 100;
  return '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';
}

/// "₹410.00" → "₹410": per-share prices in row 1 drop whole-rupee paise so
/// the average, the alert and the live price fit on one line. "₹410.55"
/// stays as it is.
String trimPaise(String price) => price.replaceFirst(RegExp(r'\.00$'), '');

/// The shared holding card, three rows with labels on the left and figures
/// on the right:
///
///   Qty 10 · Avg ₹210  [🔔 ↓ ₹200]   ₹236  +12.38%
///   ITC                                  +₹260.00
///   Invested ₹2,100.00           Total ₹2,360.00
///
/// Row 1 holds every per-share price — average, the price-alert chip, the
/// live price and the move from the average — so they compare at a glance.
/// No footer: every card is the same three rows tall. Used by single
/// holdings and by grouped stock lots.
class HoldingCard extends StatelessWidget {
  const HoldingCard({
    super.key,
    required this.title,
    required this.topLeft,
    required this.pctLabel,
    required this.gainLabel,
    required this.up,
    required this.invested,
    required this.total,
    this.alert,
    this.livePrice,
    this.menu,
    this.chevron,
    this.onTap,
    this.expanded,
  });

  final String title;

  /// "Qty 10 · Avg ₹210", or the asset type when there is no quantity.
  final String topLeft;
  final String pctLabel;
  final String gainLabel;
  final bool up;
  final String invested;

  /// Invested + profit: what the holding is worth now.
  final String total;

  /// The price-alert chip, right after the average price.
  final Widget? alert;

  /// The live price per share, shown before the return %.
  final String? livePrice;
  final Widget? menu;
  final Widget? chevron;
  final VoidCallback? onTap;

  /// Extra content below the card (the list of purchases).
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final gainColor = up ? finance.income : finance.expense;
    const tabular = [FontFeature.tabularFigures()];
    final small = AppTypography.label.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w500,
    );

    Widget labelled(String label, String value, {TextAlign? align}) =>
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$label ', style: small),
              TextSpan(
                text: value,
                style: AppTypography.label.copyWith(
                  color: palette.ink,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabular,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top: quantity and average price | return %.
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    topLeft,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: small,
                                  ),
                                ),
                                if (alert != null) ...[
                                  const SizedBox(width: 6),
                                  alert!,
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (livePrice != null) ...[
                            Text(
                              livePrice!,
                              key: const Key('holding-live'),
                              style: small.copyWith(
                                color: palette.ink,
                                fontFeatures: tabular,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            pctLabel,
                            key: const Key('holding-pct'),
                            style: AppTypography.label.copyWith(
                              color: gainColor,
                              fontWeight: FontWeight.w700,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Middle: name | profit.
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyStrong.copyWith(
                                color: palette.ink,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            gainLabel,
                            key: const Key('holding-gain'),
                            style: AppTypography.bodyStrong.copyWith(
                              color: gainColor,
                              fontSize: 16,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Bottom: invested | total (invested + profit).
                      Row(
                        children: [
                          Expanded(child: labelled('Invested', invested)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: labelled(
                              'Total',
                              total,
                              align: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (menu != null || chevron != null)
                  const SizedBox(width: AppSpacing.xxs),
                ?menu,
                ?chevron,
              ],
            ),
            ?expanded,
          ],
        ),
      ),
    );
  }
}
