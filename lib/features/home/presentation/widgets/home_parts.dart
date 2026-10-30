import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// A Home section: a 20px card with a bold title, an optional trailing action
/// or [StatusPill], and the content under it.
class HomeSection extends StatelessWidget {
  const HomeSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.section.copyWith(
                      color: context.palette.ink,
                    ),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// The "See all" action at the right of a section title.
class HomeSeeAll extends StatelessWidget {
  const HomeSeeAll({super.key, required this.onPressed, this.label = 'See all'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.chip,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(
              color: context.palette.accentText,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet empty line inside a section: tinted icon tile and one hint.
class HomeEmpty extends StatelessWidget {
  const HomeEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        IconTile(icon: icon),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyStrong.copyWith(
                  color: palette.ink,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                message,
                style: AppTypography.label.copyWith(
                  color: palette.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hairline between rows inside a section.
class HomeDivider extends StatelessWidget {
  const HomeDivider({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.palette.line);
}

/// A pastel background + foreground pair for [StatusPill].
enum HomeTone { mint, butter, coral, sky }

extension HomeToneColors on HomeTone {
  (Color, Color) of(BuildContext context) {
    final dark = context.palette.isDark;
    return switch (this) {
      HomeTone.mint => dark
          ? (AppColors.mintDark, AppColors.mintFgDark)
          : (AppColors.mintLight, AppColors.mintFgLight),
      HomeTone.butter => dark
          ? (AppColors.butterDark, AppColors.butterFgDark)
          : (AppColors.butterLight, AppColors.butterFgLight),
      HomeTone.coral => dark
          ? (AppColors.coralDark, AppColors.coralFgDark)
          : (AppColors.coralLight, AppColors.coralFgLight),
      HomeTone.sky => dark
          ? (AppColors.skyDark, AppColors.skyFgDark)
          : (AppColors.skyLight, AppColors.skyFgLight),
    };
  }
}

/// A [StatusPill] in one of the pastel tones.
class TonePill extends StatelessWidget {
  const TonePill(this.label, this.tone, {super.key, this.dot = true});

  final String label;
  final HomeTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone.of(context);
    return StatusPill(label, background: bg, foreground: fg, dot: dot);
  }
}
