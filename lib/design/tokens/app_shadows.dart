import 'package:flutter/widgets.dart';

/// Warm, low shadows — restyle spec "Shadow". Light themes tint them with the
/// ink (#111A15); dark themes use black at the same alphas.
abstract final class AppShadows {
  static Color _tint(Brightness b, double alpha) =>
      (b == Brightness.light
              ? const Color(0xFF111A15)
              : const Color(0xFF000000))
          .withValues(alpha: alpha);

  /// Resting cards.
  static List<BoxShadow> soft(Brightness b) => [
    BoxShadow(color: _tint(b, 0.04), offset: const Offset(0, 1), blurRadius: 2),
    BoxShadow(
      color: _tint(b, 0.05),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];

  /// Menus, popovers, floating buttons, pressed/hovered cards.
  static List<BoxShadow> lift(Brightness b) => [
    BoxShadow(color: _tint(b, 0.05), offset: const Offset(0, 2), blurRadius: 4),
    BoxShadow(
      color: _tint(b, 0.10),
      offset: const Offset(0, 12),
      blurRadius: 28,
    ),
  ];

  /// Dialogs.
  static List<BoxShadow> modal(Brightness b) => [
    BoxShadow(
      color: _tint(b, 0.22),
      offset: const Offset(0, 24),
      blurRadius: 64,
    ),
  ];
}
