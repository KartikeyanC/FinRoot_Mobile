import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_spacing.dart';

/// Rounded surface card (restyle spec "Card"): card fill, 1px line border,
/// 20dp radius and the warm, low [AppShadows.soft] shadow in the palette's
/// shadow tint (black on dark).
/// Optional [onTap] gives it an ink response with a 48dp min height.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        boxShadow: AppShadows.soft(palette.shadow),
      ),
      child: Material(
        color: color ?? palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  child: content,
                ),
              ),
      ),
    );
  }
}
