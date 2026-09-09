import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';
import '../../../accounts/application/accounts_providers.dart';
import '../../../summary/application/summary_providers.dart';
import '../../application/home_providers.dart';

/// The feed's headline card.
///
/// With accounts set up it leads with the **total balance across accounts**
/// (`opening_balance + dashboard_summary` delta — server-derived, ADR-0006).
/// Before then it stays honest: a count of records (not a sum) and a nudge to
/// add accounts.
class HomeSnapshotCard extends ConsumerWidget {
  const HomeSnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
    final count = ref.watch(recentActivityCountProvider).value ?? 0;

    return accounts.isEmpty
        ? _CountCard(count: count)
        : _BalanceCard(count: count);
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final total = ref.watch(totalBalanceProvider);
    final summary = ref.watch(workspaceSummaryProvider);
    final stale = summary.isLoading && summary.value == null;

    return AppCard(
      onTap: () => context.push('/accounts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total across accounts',
            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText.money(total, size: AmountSize.hero, signed: false),
          const SizedBox(height: AppSpacing.sm),
          Text(
            stale
                ? 'Updating from your last sync…'
                : '$count ${count == 1 ? 'transaction' : 'transactions'} in the last 30 days',
            style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last 30 days',
            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$count', style: t.displaySmall),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  count == 1 ? 'transaction recorded' : 'transactions recorded',
                  style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.savings_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Add accounts to see balances here.',
                  style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
