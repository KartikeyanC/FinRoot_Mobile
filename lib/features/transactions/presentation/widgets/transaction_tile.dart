import 'package:flutter/material.dart';

import '../../../../core/time/relative_time.dart';
import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../domain/transaction.dart';

/// One transaction row. Built for the Home feed in M6; the Transactions ledger
/// (M8) reuses it, which is why it takes a plain [TransactionEntity] and owns
/// no data logic.
class TransactionTile extends StatelessWidget {
  const TransactionTile(this.txn, {super.key, this.onTap, this.showDay = true});

  final TransactionEntity txn;
  final VoidCallback? onTap;

  /// Show the day label in the subtitle. The ledger, which groups by day, turns
  /// this off.
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return MergeSemantics(
      child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              _TypeAvatar(txn.type),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      txn.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText.money(txn.amount, type: txn.type),
                  if (txn.isPending || txn.hasFailedSync) ...[
                    const SizedBox(height: 2),
                    _SyncMarker(failed: txn.hasFailedSync),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[
      if (txn.title != txn.category) txn.category,
      if (showDay) RelativeTime.dayLabel(txn.occurredAt),
      if (txn.paymentMode != null) txn.paymentMode!,
    ];
    return parts.join(' · ');
  }
}

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar(this.type);
  final TxnType type;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final (IconData icon, Color color) = switch (type) {
      TxnType.income => (Icons.north_east_rounded, finance.income),
      TxnType.expense => (Icons.south_west_rounded, finance.expense),
      TxnType.transfer => (Icons.swap_horiz_rounded, finance.transfer),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _SyncMarker extends StatelessWidget {
  const _SyncMarker({required this.failed});
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = failed ? scheme.error : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          failed ? Icons.sync_problem_rounded : Icons.schedule_rounded,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          failed ? 'Not synced' : 'Pending',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
