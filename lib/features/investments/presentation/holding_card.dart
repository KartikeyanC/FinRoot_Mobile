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
///   Qty 10 · Avg ₹210 · [⏰ ₹200] · LTP ₹236      +12.38%
///   ITC                                           +₹260.00
///   Invested ₹2,100.00                    Total ₹2,360.00
///
/// Row 1 holds every per-share price — average, the price-alert chip and the
/// live price — with the move from the average on the right. Nothing is
/// ever cut off: on a narrow phone or with large text a row wraps onto a
/// second line instead. Used by single holdings and by grouped stock lots.
class HoldingCard extends StatelessWidget {
  const HoldingCard({
    super.key,
    required this.title,
    required this.facts,
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

  /// ["Qty 10", "Avg ₹210"], or the asset type when there is no quantity.
  final List<String> facts;
  final String pctLabel;
  final String gainLabel;
  final bool up;
  final String invested;

  /// Invested + profit: what the holding is worth now.
  final String total;

  /// The price-alert chip, right after the average price.
  final Widget? alert;

  /// The live price per share, last in row 1.
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

    Widget labelled(String label, String value) =>
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
                      // Top: qty · avg · alert · live | return %.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                for (final f in facts) Text(f, style: small),
                                ?alert,
                                if (livePrice != null)
                                  Text.rich(
                                    key: const Key('holding-live'),
                                    TextSpan(
                                      children: [
                                        TextSpan(text: 'LTP ', style: small),
                                        TextSpan(
                                          text: livePrice,
                                          style: small.copyWith(
                                            color: palette.ink,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: tabular,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              pctLabel,
                              key: const Key('holding-pct'),
                              style: AppTypography.label.copyWith(
                                color: gainColor,
                                fontWeight: FontWeight.w700,
                                fontFeatures: tabular,
                              ),
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
                      // Ends of the row when both fit; Total drops below
                      // Invested when they don't, never cut.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: AppSpacing.sm,
                        runSpacing: 2,
                        children: [
                          labelled('Invested', invested),
                          labelled('Total', total),
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

/// The rows of a holding's ⋮ menu: Edit, Price alert (for priced assets),
/// Delete — each with an icon, and Delete in the expense colour so it never reads as routine.
List<PopupMenuItem<String>> holdingMenuItems(
  BuildContext context, {
  required bool hasAlert,
  bool canAlert = true,
  String editLabel = 'Edit holding',
}) {
  final palette = context.palette;
  final danger = context.finance.expense;
  PopupMenuItem<String> item(
    String value,
    IconData icon,
    String label, [
    Color? color,
  ]) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: color ?? palette.muted),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: TextStyle(color: color ?? palette.ink)),
      ],
    ),
  );
  return [
    item('edit', Icons.edit_outlined, editLabel),
    if (canAlert)
      item(
        'alert',
        hasAlert ? Icons.alarm_rounded : Icons.alarm_add_rounded,
        hasAlert ? 'Price alerts' : 'Set price alert',
      ),
    item('delete', Icons.delete_outline_rounded, 'Delete', danger),
  ];
}
