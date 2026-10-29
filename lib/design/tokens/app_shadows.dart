import 'package:flutter/widgets.dart';

/// NineFlow's warm, low shadows. [tint] is the palette's `shadow` colour:
/// rgb(60,50,30) on FinRoot light (each theme has its own), black on dark —
/// the alphas are the same in both modes.
abstract final class AppShadows {
  /// Resting cards: 0 1 2 /.04, 0 4 16 /.05.
  static List<BoxShadow> soft(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.04),
      offset: const Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: tint.withValues(alpha: 0.05),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Menus, popovers, floating buttons: 0 2 4 /.05, 0 12 28 /.10.
  static List<BoxShadow> lift(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.05),
      offset: const Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: tint.withValues(alpha: 0.10),
      offset: const Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  /// Dialogs: 0 24 64 /.22.
  static List<BoxShadow> modal(Color tint) => [
    BoxShadow(
      color: tint.withValues(alpha: 0.22),
      offset: const Offset(0, 24),
      blurRadius: 64,
    ),
  ];
}
