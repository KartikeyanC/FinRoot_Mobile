import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../domain/insight.dart';

/// One insight row — icon + title + detail, tappable when it has a route.
class InsightTile extends StatelessWidget {
  const InsightTile({super.key, required this.insight, this.dense = false});

  final Insight insight;
  final bool dense;

  Color _accent(ColorScheme scheme, BuildContext context) => switch (insight.kind) {
    InsightKind.positive => context.finance.income,
    InsightKind.alert => scheme.error,
    InsightKind.watch => scheme.tertiary,
    InsightKind.neutral => scheme.onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accent = _accent(scheme, context);
    final tappable = insight.route != null;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(insight.icon, size: 18, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: (dense ? tt.bodyMedium : tt.bodyLarge)?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.detail,
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (tappable)
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    if (!tappable) return content;
    return InkWell(
      onTap: () => context.push(insight.route!),
      borderRadius: AppRadius.field,
      child: content,
    );
  }
}
