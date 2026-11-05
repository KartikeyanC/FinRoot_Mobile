import 'package:flutter/material.dart';

import '../theme/finance_colors.dart';
import '../tokens/app_palette.dart';
import '../tokens/app_spacing.dart';
import '../tokens/app_typography.dart';
import 'app_card.dart';

/// The list layout every money screen shares, taken from Investments:
///
///   ┌ SummaryPanel ─────────────────────────────┐
///   │ Invested                          Current │
///   │ 63,753.07                       73,324.80 │
///   │ ───────────────────────────────────────── │
///   │ P&L                     +9,571.73 [15.0%] │
///   └───────────────────────────────────────────┘
///   ── LedgerBand: Stocks · 3 ─────── +3,473.39   (optional grouping)
///   LedgerRow   meta                    metaRight
///               Title                       value
///               detail [tag]          detailRight
///   ──────────── hairline ───────────────────────
///
/// Rows are flat and full width; labels run down the left edge and every
/// figure ends on one right edge. Nothing is cut off — long text wraps.

const _tabular = [FontFeature.tabularFigures()];

/// Two figures side by side, then (optionally) a footer line under a
/// hairline: Invested | Current · P&L, Income | Spent · Left, …
class SummaryPanel extends StatelessWidget {
  const SummaryPanel({
    super.key,
    required this.left,
    this.right,
    this.footLabel,
    this.footValue,
    this.footColor,
    this.footPill,
    this.footKey,
    this.child,
  });

  /// (label, figure) — top left.
  final (String, String) left;

  /// (label, figure) — top right.
  final (String, String)? right;
  final String? footLabel;
  final String? footValue;
  final Color? footColor;

  /// A small pill after the footer figure ("+15.01%").
  final Widget? footPill;
  final Key? footKey;

  /// Anything extra at the bottom (a split bar).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = AppTypography.label.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    final figure = AppTypography.title.copyWith(
      color: palette.ink,
      fontFeatures: _tabular,
    );

    Widget cell((String, String) c, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(c.$1, style: label),
        const SizedBox(height: 4),
        Text(c.$2, style: figure),
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              cell(left, CrossAxisAlignment.start),
              if (right != null) cell(right!, CrossAxisAlignment.end),
            ],
          ),
          if (footLabel != null || footValue != null) ...[
            Divider(height: AppSpacing.xl, color: palette.line),
            Row(
              children: [
                if (footLabel != null)
                  Text(
                    footLabel!,
                    style: AppTypography.body.copyWith(color: palette.muted),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: [
                      if (footValue != null)
                        Text(
                          footValue!,
                          key: footKey,
                          style: AppTypography.title.copyWith(
                            color: footColor ?? palette.ink,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ?footPill,
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (child != null) ...[const SizedBox(height: AppSpacing.md), child!],
        ],
      ),
    );
  }
}

/// The band above a group of rows: name and count on the left, the group's
/// figure on the right edge where the rows' figures sit.
class LedgerBand extends StatelessWidget {
  const LedgerBand({
    super.key,
    required this.title,
    this.count,
    this.value,
    this.valueColor,
  });

  final String title;
  final int? count;
  final String? value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      color: palette.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null ? title : '$title  ·  $count',
              style: AppTypography.bodyStrong.copyWith(color: palette.ink),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: AppTypography.label.copyWith(
                color: valueColor ?? palette.muted,
                fontWeight: FontWeight.w700,
                fontFeatures: _tabular,
              ),
            ),
        ],
      ),
    );
  }
}

/// The hairline between rows (and above the first one).
class LedgerDivider extends StatelessWidget {
  const LedgerDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.palette.line);
}

/// One flat, full-width row of a money list — up to three lines, labels on
/// the left, figures on one right edge:
///
///   meta                       metaRight     ← small, muted (optional)
///   title                          value     ← the main line
///   detail [detailTag]       detailRight     ← small (optional)
///
/// While its list is selecting ([selecting]), a check circle leads the row
/// and a tap toggles it instead of opening it.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.title,
    this.meta,
    this.metaRight,
    this.metaRightColor,
    this.value,
    this.valueColor,
    this.valueKey,
    this.valueLabel,
    this.detail,
    this.detailTag,
    this.detailRight,
    this.detailRightColor,
    this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  final String title;
  final String? meta;
  final String? metaRight;
  final Color? metaRightColor;
  final String? value;
  final Color? valueColor;
  final Key? valueKey;

  /// What a screen reader says for [value] ("Expense ₹200", not
  /// "minus rupee sign 200").
  final String? valueLabel;
  final String? detail;

  /// A small status widget after [detail] (an alarm tag, a "Due" pill).
  final Widget? detailTag;
  final String? detailRight;
  final Color? detailRightColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = AppTypography.label.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    final strongSmall = muted.copyWith(
      color: palette.ink,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
    );
    final main = AppTypography.bodyStrong.copyWith(fontSize: 16);

    Widget line(Widget left, Widget? right, {bool top = true}) => Row(
      crossAxisAlignment: top
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(child: left),
        if (right != null) ...[const SizedBox(width: AppSpacing.md), right],
      ],
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (meta != null || metaRight != null) ...[
          line(
            Text(meta ?? '', style: muted),
            metaRight == null
                ? null
                : Text(
                    metaRight!,
                    style: muted.copyWith(
                      color: metaRightColor ?? palette.muted,
                      fontWeight: FontWeight.w600,
                      fontFeatures: _tabular,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
        ],
        line(
          Text(title, style: main.copyWith(color: palette.ink)),
          value == null
              ? null
              : Text(
                  value!,
                  key: valueKey,
                  semanticsLabel: valueLabel,
                  style: main.copyWith(
                    color: valueColor ?? palette.ink,
                    fontFeatures: _tabular,
                  ),
                ),
        ),
        if (detail != null || detailTag != null || detailRight != null) ...[
          const SizedBox(height: 6),
          line(
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (detail != null) Text(detail!, style: muted),
                ?detailTag,
              ],
            ),
            detailRight == null
                ? null
                : Text(
                    detailRight!,
                    style: strongSmall.copyWith(
                      color: detailRightColor ?? palette.ink,
                    ),
                  ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      selected: selecting ? selected : null,
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenGutter,
              vertical: AppSpacing.md,
            ),
            child: selecting
                ? Row(
                    children: [
                      SelectCheck(on: selected),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: content),
                    ],
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

/// The tick circle that leads a row while its list is selecting.
class SelectCheck extends StatelessWidget {
  const SelectCheck({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? palette.accent : Colors.transparent,
        border: Border.all(
          color: on ? palette.accent : palette.faint,
          width: 2,
        ),
      ),
      child: on
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );
  }
}

/// "+1,234.00" in the income colour, "-1,234.00" in the expense colour.
Color signColor(BuildContext context, double v) =>
    v < 0 ? context.finance.expense : context.finance.income;
