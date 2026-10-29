import 'package:flutter/material.dart';

/// Type scale — NineFlow's: Inter for everything, headings bold with tight
/// tracking (-0.025em), tabular figures on money.
///
/// NineFlow scale (sp, size/line-height) and the Material slots it fills:
/// - display 30/36 bold   → display*, headlineLarge, headlineMedium
/// - title 18/28 bold     → headlineSmall, titleLarge
/// - section 16/24 bold   → titleMedium
/// - body-strong 14/20 600 → titleSmall, labelLarge (buttons)
/// - body 14/20           → bodyLarge, bodyMedium
/// - label 12/16 600      → labelMedium
/// - caption 11/16        → bodySmall
/// - micro 10/14 600      → labelSmall (nav labels)
abstract final class AppTypography {
  /// Inter, bundled in `assets/fonts` (static instances of the variable font).
  static const String fontFamily = 'Inter';

  /// Headings and figures use the same face now; kept as a name so call sites
  /// that ask for "the display face" stay meaningful.
  static const String displayFamily = fontFamily;

  /// Heading letter-spacing as a fraction of font size (-0.025em).
  static const double headingTracking = -0.025;

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    bool heading = false,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: heading ? size * headingTracking : 0,
  );

  static final TextStyle display = _style(
    30,
    36,
    FontWeight.w700,
    heading: true,
  );
  static final TextStyle title = _style(18, 28, FontWeight.w700, heading: true);
  static final TextStyle section = _style(
    16,
    24,
    FontWeight.w700,
    heading: true,
  );
  static final TextStyle body = _style(14, 20, FontWeight.w400);
  static final TextStyle bodyStrong = _style(14, 20, FontWeight.w600);
  static final TextStyle label = _style(12, 16, FontWeight.w600);
  static final TextStyle caption = _style(11, 16, FontWeight.w400);
  static final TextStyle micro = _style(10, 14, FontWeight.w600);

  /// Applied on top of the Material 3 baseline text theme (keeps its colours
  /// and decorations, replaces family, size, height, weight and tracking).
  static TextTheme applyTo(TextTheme base) {
    TextStyle? m(TextStyle? b, TextStyle s) => b?.merge(s) ?? s;
    return base.copyWith(
      displayLarge: m(base.displayLarge, display),
      displayMedium: m(base.displayMedium, display),
      displaySmall: m(base.displaySmall, display),
      headlineLarge: m(base.headlineLarge, display),
      headlineMedium: m(base.headlineMedium, display),
      headlineSmall: m(base.headlineSmall, title),
      titleLarge: m(base.titleLarge, title),
      titleMedium: m(base.titleMedium, section),
      titleSmall: m(base.titleSmall, bodyStrong),
      bodyLarge: m(base.bodyLarge, body),
      bodyMedium: m(base.bodyMedium, body),
      bodySmall: m(base.bodySmall, caption),
      labelLarge: m(base.labelLarge, bodyStrong),
      labelMedium: m(base.labelMedium, label),
      labelSmall: m(base.labelSmall, micro),
    );
  }

  /// A small upper-case card heading with wide tracking.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Inline money, e.g. a transaction row amount.
  static const TextStyle money = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.2,
  );

  /// A section total, e.g. account balance in a list.
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    letterSpacing: -0.55,
    height: 1.1,
  );

  /// The one big number on a screen — Home "Available", Quick Add amount.
  static const TextStyle moneyHero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w800,
    fontFeatures: _tabular,
    letterSpacing: -1.0,
    height: 1.05,
  );
}
