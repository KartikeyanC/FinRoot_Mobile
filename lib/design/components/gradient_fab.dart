import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/app_shadows.dart';

/// NineFlow's "+" on phones: a circle in the colour theme's gradient, white
/// icon, `shadow-lift`. The app shell docks one in the middle of the bottom
/// bar; it is the app's single quick-add action.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.icon = Icons.add_rounded,
    this.size = defaultSize,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;
  final double size;

  static const double defaultSize = 56;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: palette.gradient,
          boxShadow: AppShadows.lift(palette.shadow),
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: size * 0.5, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// A screen's own floating action ("+ Tracker", "+ Goal"): the same fully
/// round gradient button as every other primary action, with a label.
///
/// Drop-in for `FloatingActionButton.extended` — same `icon`, `label` and
/// `onPressed` — so a screen's add button follows the design system (full
/// radius, brand gradient, white bold text) instead of Material's solid FAB.
class GradientExtendedFab extends StatelessWidget {
  const GradientExtendedFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final Widget icon;
  final Widget label;
  final String? tooltip;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: palette.gradient,
        boxShadow: AppShadows.lift(palette.shadow),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white, size: 20),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [icon, const SizedBox(width: 8), label],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
