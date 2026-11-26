import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../split/application/split_providers.dart';
import '../../split/data/split_dues_gateway.dart';
import '../../split/domain/split_dues.dart';
import '../../split/presentation/split_state_views.dart';
import '../domain/trip.dart';

/// Settle up a friends/family trip (web TripSettleUp): who pays whom in the
/// fewest transfers. Recording writes `split_dues` rows only — trip money
/// never reaches the ledger.
class TripSettleUpCard extends ConsumerStatefulWidget {
  const TripSettleUpCard({
    super.key,
    required this.trip,
    required this.canWrite,
  });

  final Trip trip;
  final bool canWrite;

  @override
  ConsumerState<TripSettleUpCard> createState() => _TripSettleUpCardState();
}

class _TripSettleUpCardState extends ConsumerState<TripSettleUpCard> {
  bool _busy = false;

  Future<void> _save(List<Transfer> transfers, {required bool settled}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final rows = [
        for (final d in transfersToDues(
          transfers,
          widget.trip.id,
          widget.trip.name,
        ))
          d.copyWith(settled: settled),
      ];
      final ok = await ref.read(splitDuesControllerProvider).record(rows);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (settled ? 'Marked settled' : 'Added to Who owes what')
                : kSplitDuesMissingMessage,
          ),
        ),
      );
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfers = tripTransfers(widget.trip);
    if (transfers.isEmpty) return const SizedBox.shrink();
    final palette = context.palette;
    final dues = ref.watch(splitDuesProvider);
    final missing = dues.error is SplitDuesMissing;
    final recorded = [
      for (final d in dues.value ?? const <SplitDue>[])
        if (d.source == DueSource.trip && d.sourceId == widget.trip.id) d,
    ];
    final allSettled =
        recorded.isNotEmpty && recorded.every((d) => d.isSettled);
    final mineInvolved = transfers.any((t) => t.from == kMe || t.to == kMe);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Settle up'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in transfers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          t.from,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: palette.muted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t.to,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ),
                      Text(
                        MoneyFormat.money(t.amount, currency: t.currency),
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              if (transfers.any((t) => t.from != kMe && t.to != kMe)) ...[
                const SizedBox(height: AppSpacing.xs),
                const InlineNote(
                  'Transfers between companions are shown, not recorded.',
                  icon: Icons.info_outline,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (missing)
                const InlineNote(kSplitDuesMissingMessage, warning: true)
              else if (recorded.isNotEmpty)
                InlineNote(
                  allSettled ? 'Settled.' : 'Recorded in Who owes what.',
                )
              else if (widget.canWrite && mineInvolved)
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: _busy || dues.isLoading
                          ? null
                          : () => _save(transfers, settled: false),
                      child: const Text('Track in Who owes what'),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || dues.isLoading
                          ? null
                          : () => _save(transfers, settled: true),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark settled'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
