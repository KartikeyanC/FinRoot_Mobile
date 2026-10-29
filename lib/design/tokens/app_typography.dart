import 'package:flutter/material.dart';

/// Type scale — the web dashboard's: IBM Plex Sans for text, Space Grotesk
/// (its `font-display`) for headings, titles and money figures.
///
/// Financial numbers must be easy to scan (brief §32): tabular figures, strong
/// weight, restrained letter-spacing. [money] / [moneyLarge] / [moneyHero] are
/// the money styles; everything else derives from Material's [TextTheme].
abstract final class AppTypography {
  /// Body text (web `--font-body`).
  static const String fontFamily = 'IBMPlexSans';

  /// Headings and numbers (web `font-display`).
  static const String displayFamily = 'SpaceGrotesk';

  /// Heading letter-spacing as a fraction of font size (-0.025em).
  static const double headingTracking = -0.025;

  /// Applied on top of the Material 3 baseline text theme.
  static TextTheme applyTo(TextTheme base) {
    final body = base.apply(fontFamily: fontFamily);
    // Headings are bold with tight tracking (restyle spec: -0.025em).
    TextStyle? display(TextStyle? s, FontWeight w, [double? height]) =>
        s?.copyWith(
          fontFamily: displayFamily,
          fontWeight: w,
          height: height,
          letterSpacing: (s.fontSize ?? 14) * headingTracking,
        );
    return body.copyWith(
      displayLarge: display(body.displayLarge, FontWeight.w700),
      displayMedium: display(body.displayMedium, FontWeight.w700),
      displaySmall: display(body.displaySmall, FontWeight.w700),
      headlineLarge: display(body.headlineLarge, FontWeight.w700, 1.15),
      headlineMedium: display(body.headlineMedium, FontWeight.w700, 1.15),
      headlineSmall: display(body.headlineSmall, FontWeight.w700, 1.2),
      titleLarge: display(body.titleLarge, FontWeight.w700, 1.2),
      titleMedium: display(body.titleMedium, FontWeight.w600),
      titleSmall: display(body.titleSmall, FontWeight.w600),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: body.bodyMedium?.copyWith(height: 1.4),
    );
  }

  /// The web's card heading: small, semibold, upper case, wide tracking.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: displayFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Inline money, e.g. a transaction row amount.
  static const TextStyle money = TextStyle(
    fontFamily: displayFamily,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.2,
  );

  /// A section total, e.g. account balance in a list.
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: displayFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.4,
    height: 1.1,
  );

  /// The one big number on a screen — Home "Available", Quick Add amount.
  static const TextStyle moneyHero = TextStyle(
    fontFamily: displayFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
    letterSpacing: -1.0,
    height: 1.05,
  );
}
