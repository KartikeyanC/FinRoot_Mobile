/// 4dp spacing scale. Use these names, never raw numbers, in layout code.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Standard screen edge padding on a phone.
  static const double screenGutter = 16;

  /// Minimum interactive target (Material / WCAG 2.2 target size).
  static const double minTouchTarget = 48;
}
