import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';
import '../../../../navigation/destinations.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../../application/home_providers.dart';

/// The feed's "Recent activity" — the last handful of transactions from the
/// cache, newest first, with a link to the full ledger (M8).
class HomeRecentActivity extends ConsumerWidget {
  const HomeRecentActivity({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Recent activity',
          action: recent.value?.isNotEmpty == true
              ? TextButton(
                  onPressed: () =>
                      context.go(AppDestination.transactions.path),
                  child: const Text('See all'),
                )
              : null,
        ),
        recent.when(
          loading: () => const _RecentSkeleton(),
          error: (error, stack) => AppCard(
            child: Text(
              'Recent activity couldn\'t load right now.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          data: (txns) => txns.isEmpty
              ? const _RecentEmpty()
              : _RecentList(txns: txns),
        ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.txns});
  final List<TransactionEntity> txns;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (var i = 0; i < txns.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            TransactionTile(txns[i]),
          ],
        ],
      ),
    );
  }
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nothing recorded yet',
                  style: t.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap the + button to record your first expense.',
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _Bar(width: 40, height: 40, color: base, radius: 20),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bar(width: 140, height: 12, color: base),
                      const SizedBox(height: AppSpacing.sm),
                      _Bar(width: 90, height: 10, color: base),
                    ],
                  ),
                ),
                _Bar(width: 56, height: 12, color: base),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.width,
    required this.height,
    required this.color,
    this.radius = 4,
  });

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
