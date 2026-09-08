import 'package:flutter/material.dart';

import '../../domain/constants.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Category chip on a transaction row. Neutral by default; a palette per
/// category can be layered later without changing call sites.
class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key});
  final String category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pill(
      label: category,
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
    );
  }
}

/// Tracker badge. Deliberately a single neutral tint for every tracker — a
/// tracker wearing the category palette would read as a second category, the
/// exact confusion trackers must avoid (web `src/lib/trackers.ts`). Shows the
/// "T-" display convention; the stored name never carries it (web BR-077).
class TrackerBadge extends StatelessWidget {
  const TrackerBadge(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pill(
      label: trackerDisplayLabel(name),
      background: scheme.primary.withValues(alpha: 0.12),
      foreground: scheme.primary,
      icon: Icons.donut_large_rounded,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
