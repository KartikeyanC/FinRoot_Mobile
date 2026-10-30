import 'package:flutter/material.dart';

import '../../../../core/time/relative_time.dart';
import '../../../../core/widgets/date_time_field.dart';
import '../../../../design/design.dart';
import '../../domain/transaction.dart';
import 'category_style.dart';

/// One transaction row: category tile, title, muted meta line, amount and (when
/// not yet synced) a sync pill at the right. The Home feed, search and the
/// ledger all use it; it takes a plain [TransactionEntity] and owns no data
/// logic.
class TransactionTile extends StatelessWidget {
  const TransactionTile(
    this.txn, {
    super.key,
    this.onTap,
    this.showDay = true,
    this.card = false,
    this.selected = false,
  });

  final TransactionEntity txn;
  final VoidCallback? onTap;

  /// Show the day label in the subtitle. The ledger, which groups by day, turns
  /// this off.
  final bool showDay;

  /// Render as a standalone [ListRow] card (the ledger and tracker detail).
  /// Off for callers that already sit inside a card.
  final bool card;

  /// Highlights the row (tablet two-pane selection).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final trailing = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AmountText.money(txn.amount, type: txn.type),
        if (txn.isPending || txn.hasFailedSync) ...[
          const SizedBox(height: 4),
          _SyncPill(failed: txn.hasFailedSync),
        ],
      ],
    );

    if (card) {
      final palette = context.palette;
      return MergeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: selected
                ? Border.all(color: palette.accent, width: 1.5)
                : null,
          ),
          child: ListRow(
            leading: CategoryTile(category: txn.category, type: txn.type),
            title: txn.title,
            subtitle: _subtitle(),
            trailing: trailing,
            onTap: onTap,
          ),
        ),
      );
    }

    final palette = context.palette;
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                CategoryTile(category: txn.category, type: txn.type, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                trailing,
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
      DateTimeField.formatTime(txn.occurredAt).toLowerCase(),
      if (txn.paymentMode != null) txn.paymentMode!,
    ];
    return parts.isEmpty ? txn.type.name : parts.join(' · ');
  }
}

class _SyncPill extends StatelessWidget {
  const _SyncPill({required this.failed});
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return StatusPill(
      failed ? 'Not synced' : 'Pending',
      icon: failed ? Icons.sync_problem_rounded : Icons.schedule_rounded,
      background: failed
          ? (dark ? AppColors.coralDark : AppColors.coralLight)
          : (dark ? AppColors.butterDark : AppColors.butterLight),
      foreground: failed
          ? (dark ? AppColors.coralFgDark : AppColors.coralFgLight)
          : (dark ? AppColors.butterFgDark : AppColors.butterFgLight),
    );
  }
}
