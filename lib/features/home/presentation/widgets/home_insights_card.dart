import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../insights/application/insights_providers.dart';
import '../../../insights/presentation/insight_tile.dart';
import 'home_parts.dart';

/// Home "Insights" — the top few derived observations (M15). Reads the
/// on-device rule engine; hides itself when there is nothing to say.
class HomeInsightsCard extends ConsumerWidget {
  const HomeInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(homeInsightsProvider);
    if (insights.isEmpty) return const SizedBox.shrink();

    final all = ref.watch(insightsProvider);

    return HomeSection(
      title: 'Insights',
      trailing: all.length > insights.length
          ? HomeSeeAll(
              label: 'All ${all.length}',
              onPressed: () => context.push('/insights'),
            )
          : null,
      child: Column(
        children: [
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0) const HomeDivider(),
            InsightTile(insight: insights[i], dense: true),
          ],
        ],
      ),
    );
  }
}

/// Whether [HomeInsightsCard] draws anything: there is at least one insight.
bool homeInsightsShow(WidgetRef ref) =>
    ref.watch(homeInsightsProvider).isNotEmpty;
