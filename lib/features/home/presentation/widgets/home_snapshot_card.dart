import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/design.dart';
import '../../application/home_providers.dart';

/// The feed's headline card.
///
/// It deliberately does **not** show a balance or a spend total: money is
/// server-derived (ADR-0006) and the figures land with Accounts in M8. What it
/// can show honestly today is how much has been *recorded* — a count of cached
/// transactions, not a sum — plus a clear note about what's still coming.
class HomeSnapshotCard extends ConsumerWidget {
  const HomeSnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final count = ref.watch(recentActivityCountProvider).value ?? 0;

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
                  style: t.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
                  'Balances and spending totals arrive with Accounts.',
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
