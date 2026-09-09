import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';
import '../../../insights/application/insights_providers.dart';
import '../../../insights/presentation/insight_tile.dart';

/// Home "Insights" — the top few derived observations (M15). Reads the
/// on-device rule engine; hides itself when there is nothing to say.
class HomeInsightsCard extends ConsumerWidget {
  const HomeInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(homeInsightsProvider);
    if (insights.isEmpty) return const SizedBox.shrink();

    final all = ref.watch(insightsProvider);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 20,
                  color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text('Insights', style: tt.titleSmall),
              const Spacer(),
              if (all.length > insights.length)
                TextButton(
                  onPressed: () => context.push('/insights'),
                  child: Text('All ${all.length}'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final insight in insights)
            InsightTile(insight: insight, dense: true),
        ],
      ),
    );
  }
}
