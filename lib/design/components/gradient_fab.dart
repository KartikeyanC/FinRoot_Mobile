import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/app_shadows.dart';

/// NineFlow's floating "+" on phones: a 56dp circle in the colour theme's
/// gradient, white icon, `shadow-lift`. One per screen — the main add action.
class GradientFab extends StatelessWidget {
  const GradientFab({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.icon = Icons.add_rounded,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final IconData icon;

  static const double size = 56;

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
              child: Icon(icon, size: 28, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
