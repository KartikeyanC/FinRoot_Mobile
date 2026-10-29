import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';

/// Button styling the [ButtonStyle] color properties can't express.
///
/// The primary action wears the one brand gradient (restyle spec: #0E8466 →
/// #0A5E48, left to right). [AppTheme] installs [gradientBackground] as the
/// `filledButtonTheme`'s background layer, so every plain [FilledButton] /
/// [FilledButton.icon] gets it with no call-site change. The two filled
/// variants that must NOT be green-gradient opt out:
/// - tonal buttons: `style: AppButtonStyles.noGradient`
/// - confirm-delete buttons: `style: AppButtonStyles.destructive`
abstract final class AppButtonStyles {
  /// Left-to-right brand gradient.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [AppColors.brandA, AppColors.brandB],
  );

  /// [ButtonStyle.backgroundBuilder] that paints [brandGradient] behind the
  /// label. It is drawn as an [Ink] on the button's own [Material], so ink
  /// splashes still show on top and the button's shape clips it. A disabled
  /// button falls back to the theme's flat disabled fill.
  static Widget gradientBackground(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    if (states.contains(WidgetState.disabled)) return _plain(child);
    return Ink(
      decoration: const BoxDecoration(gradient: brandGradient),
      child: child,
    );
  }

  static Widget _plainBackground(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) => _plain(child);

  static Widget _plain(Widget? child) => child ?? const SizedBox.shrink();

  /// Keeps a [FilledButton] (e.g. `FilledButton.tonal`) on its flat fill.
  static const ButtonStyle noGradient = ButtonStyle(
    backgroundBuilder: _plainBackground,
  );

  /// Solid danger fill with white text — only for confirming a delete.
  static final ButtonStyle destructive = FilledButton.styleFrom(
    backgroundColor: AppColors.dangerFill,
    foregroundColor: Colors.white,
  ).copyWith(backgroundBuilder: _plainBackground);
}
