import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../summary/application/summary_providers.dart';
import '../application/insights_providers.dart';
import 'insight_tile.dart';

/// Insights (M15) — every derived observation about the workspace's money,
/// generated on device. Not menu-gated; reads roll-ups that are themselves
/// gated where relevant.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workspaceSummaryProvider);
          ref.invalidate(recurringItemsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.lg,
            AppSpacing.screenGutter,
            AppSpacing.huge,
          ),
          children: [
            Text(
              'Patterns from your income, spending, budgets and goals — worked '
              'out on this device.',
              style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < insights.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              InsightTile(insight: insights[i]),
            ],
          ],
        ),
      ),
    );
  }
}
