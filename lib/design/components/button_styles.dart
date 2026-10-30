import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_palette.dart';

/// Button styling the [ButtonStyle] color properties can't express.
///
/// The primary action wears the colour theme's one gradient (`brand-a` →
/// `brand-b`, left to right; FinRoot: #0E8466 → #0A5E48). [AppTheme] installs
/// [gradientBackground] as the `filledButtonTheme`'s background layer, so every
/// plain [FilledButton] / [FilledButton.icon] gets it with no call-site
/// change. The two filled variants that must NOT wear it opt out:
/// - tonal buttons: `style: AppButtonStyles.noGradient`
/// - confirm-delete buttons: `style: AppButtonStyles.destructive`
abstract final class AppButtonStyles {
  /// The active colour theme's gradient.
  static LinearGradient gradientOf(BuildContext context) =>
      context.palette.gradient;

  /// [ButtonStyle.backgroundBuilder] that paints the theme gradient behind the
  /// label. It is drawn as an [Ink] on the button's own [Material], so ink
  /// splashes still show on top and the button's shape clips it. A disabled
  /// button falls back to the theme's flat disabled fill.
  static Widget gradientBackground(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    if (states.contains(WidgetState.disabled)) return _plain(child);
    // Label and icon are white on every gradient (the scheme's onPrimary is
    // dark on dark-mode accents, which suits solid accent fills only).
    // Painted in its own pill shape: the button's clip is not guaranteed to
    // reach a builder-made background, and an unclipped gradient shows square
    // corners (seen on the Reminders empty state).
    return Ink(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        gradient: gradientOf(context),
      ),
      child: IconTheme.merge(
        data: const IconThemeData(color: Colors.white),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white),
          child: _plain(child),
        ),
      ),
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

  /// Solid danger (#D7373D) with white text — only for confirming a delete.
  static final ButtonStyle destructive = FilledButton.styleFrom(
    backgroundColor: AppColors.dangerFill,
    foregroundColor: Colors.white,
  ).copyWith(backgroundBuilder: _plainBackground);
}
