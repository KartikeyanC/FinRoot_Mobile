import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../domain/insight.dart';

/// One insight row — a tinted icon tile, bold title and a muted detail,
/// tappable (with a chevron) when it has a route. Sits inside a card.
class InsightTile extends StatelessWidget {
  const InsightTile({super.key, required this.insight, this.dense = false});

  final Insight insight;
  final bool dense;

  /// Tile background and icon colour for the insight's tone.
  (Color, Color) _tone(BuildContext context) {
    final palette = context.palette;
    final dark = palette.isDark;
    return switch (insight.kind) {
      InsightKind.positive =>
        dark
            ? (AppColors.mintDark, AppColors.mintFgDark)
            : (AppColors.mintLight, AppColors.mintFgLight),
      InsightKind.alert =>
        dark
            ? (AppColors.coralDark, AppColors.coralFgDark)
            : (AppColors.coralLight, AppColors.coralFgLight),
      InsightKind.watch =>
        dark
            ? (AppColors.butterDark, AppColors.butterFgDark)
            : (AppColors.butterLight, AppColors.butterFgLight),
      InsightKind.neutral => (palette.tint, palette.accentText),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (bg, fg) = _tone(context);
    final tappable = insight.route != null;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          IconTile(
            icon: insight.icon,
            size: dense ? 36 : 44,
            tint: bg,
            color: fg,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: AppTypography.label.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (tappable)
            Icon(Icons.chevron_right_rounded, color: palette.faint),
        ],
      ),
    );

    if (!tappable) return content;
    return InkWell(
      onTap: () => context.push(insight.route!),
      borderRadius: AppRadius.tile,
      child: content,
    );
  }
}
