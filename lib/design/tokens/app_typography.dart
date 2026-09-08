import 'package:flutter/material.dart';

/// Type scale. FinRoot uses the platform system font (San Francisco / Roboto)
/// for body and a tighter, heavier treatment for money figures.
///
/// Financial numbers must be easy to scan (brief §32): tabular figures, strong
/// weight, restrained letter-spacing. [money] / [moneyLarge] / [moneyHero] are
/// the money styles; everything else derives from Material's [TextTheme].
abstract final class AppTypography {
  static const String? fontFamily = null; // system default

  /// Applied on top of the Material 3 baseline text theme.
  static TextTheme applyTo(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
    );
  }

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Inline money, e.g. a transaction row amount.
  static const TextStyle money = TextStyle(
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.2,
  );

  /// A section total, e.g. account balance in a list.
  static const TextStyle moneyLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.4,
    height: 1.1,
  );

  /// The one big number on a screen — Home "Available", Quick Add amount.
  static const TextStyle moneyHero = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
    letterSpacing: -1.0,
    height: 1.05,
  );
}
