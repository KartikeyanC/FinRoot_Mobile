import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../recurring/application/recurring_providers.dart';
import '../../summary/application/summary_providers.dart';
import '../application/insights_providers.dart';
import '../domain/insight.dart';
import 'insight_tile.dart';

/// Insights (M15) — every derived observation about the workspace's money,
/// generated on device. Not menu-gated; reads roll-ups that are themselves
/// gated where relevant.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(insightsProvider);
    final finance = context.finance;

    int count(InsightKind k) => insights.where((i) => i.kind == k).length;

    return AppPage(
      title: 'Insights',
      subtitle:
          'Patterns from your income, spending, budgets and goals, worked '
          'out on this device.',
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workspaceSummaryProvider);
          ref.invalidate(recurringItemsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.sm,
            AppSpacing.screenGutter,
            AppSpacing.huge,
          ),
          children: [
            if (insights.isNotEmpty) ...[
              StatStrip([
                Stat(
                  '${count(InsightKind.alert)}',
                  'Needs attention',
                  color: finance.expense,
                ),
                Stat(
                  '${count(InsightKind.watch)}',
                  'Worth a look',
                  color: finance.warning,
                ),
                Stat(
                  '${count(InsightKind.positive)}',
                  'Going well',
                  color: finance.income,
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
            ],
            for (final insight in insights) ...[
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: InsightTile(insight: insight),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
