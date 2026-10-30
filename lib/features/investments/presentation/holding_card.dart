import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';

/// The shared holding row: symbol tile, name, asset/units line, optional live
/// line and facts, current value and a gain pill at the right. Used by single
/// holdings and by grouped stock lots.
class HoldingCard extends StatelessWidget {
  const HoldingCard({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.gainLabel,
    required this.up,
    this.live,
    this.facts,
    this.menu,
    this.chevron,
    this.onTap,
    this.expanded,
  });

  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final String value;
  final String gainLabel;
  final bool up;
  final String? live;
  final Widget? facts;
  final Widget? menu;
  final Widget? chevron;
  final VoidCallback? onTap;

  /// Extra content below the row (the list of purchases).
  final Widget? expanded;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ToneTile(icon: icon, tone: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (live != null)
                        Text(
                          live!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label.copyWith(
                            color: finance.income,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TonePill(
                      gainLabel,
                      up ? Tones.mint(context) : Tones.coral(context),
                      dot: false,
                    ),
                  ],
                ),
                ?menu,
                ?chevron,
              ],
            ),
            if (facts != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: facts,
              ),
            ?expanded,
          ],
        ),
      ),
    );
  }
}
