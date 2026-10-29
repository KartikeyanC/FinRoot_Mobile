import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_palette.dart';

/// Theme-aware semantic colors that Material's [ColorScheme] does not cover:
/// the direction of money and the status tones. Consumed via
/// `Theme.of(context).extension<FinanceColors>()!` or the
/// `context.finance` helper.
@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.success,
    required this.warning,
    required this.danger,
    required this.positiveContainer,
    required this.warningContainer,
    required this.brandText,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color success;
  final Color warning;
  final Color danger;
  final Color positiveContainer;
  final Color warningContainer;

  /// Accent for text and icons (not fills) — the palette's `accentText`,
  /// 4.5:1+ on card, page and tint.
  final Color brandText;

  /// Semantic colours for a palette. Money direction and status use the
  /// shared pastel `*Fg` tones (readable on every theme's card, page and
  /// tint); the accent tint and accent text follow the colour theme.
  factory FinanceColors.forPalette(AppPalette p) {
    final light = !p.isDark;
    return FinanceColors(
      income: light ? AppColors.mintFgLight : AppColors.mintFgDark,
      expense: light ? AppColors.coralFgLight : AppColors.coralFgDark,
      transfer: light ? AppColors.skyFgLight : AppColors.skyFgDark,
      success: light ? AppColors.mintFgLight : AppColors.mintFgDark,
      warning: light ? AppColors.butterFgLight : AppColors.butterFgDark,
      danger: light ? AppColors.coralFgLight : AppColors.coralFgDark,
      positiveContainer: p.tint,
      warningContainer: light ? AppColors.butterLight : AppColors.butterDark,
      brandText: p.accentText,
    );
  }

  static final light = FinanceColors.forPalette(AppPalette.finrootLight);
  static final dark = FinanceColors.forPalette(AppPalette.finrootDark);

  @override
  FinanceColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? success,
    Color? warning,
    Color? danger,
    Color? positiveContainer,
    Color? warningContainer,
    Color? brandText,
  }) {
    return FinanceColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      warningContainer: warningContainer ?? this.warningContainer,
      brandText: brandText ?? this.brandText,
    );
  }

  @override
  FinanceColors lerp(ThemeExtension<FinanceColors>? other, double t) {
    if (other is! FinanceColors) return this;
    return FinanceColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      brandText: Color.lerp(brandText, other.brandText, t)!,
    );
  }
}

extension FinanceColorsX on BuildContext {
  /// Shorthand for the [FinanceColors] extension on the active theme.
  FinanceColors get finance => Theme.of(this).extension<FinanceColors>()!;
}
