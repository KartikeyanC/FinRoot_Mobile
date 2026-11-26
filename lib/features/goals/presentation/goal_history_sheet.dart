import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../application/goals_providers.dart';
import '../domain/goal.dart';
import '../domain/goal_history.dart';

final _date = DateFormat('d MMM yyyy');

/// A goal's contribution history (date, amount, note), newest first — the same
/// `goal_contributions` rows the web shows. Read-only: a mistaken deposit is
/// undone with "Take back", which is logged too, so the list adds up to what
/// moved.
Future<void> openGoalHistorySheet(BuildContext context, GoalEntity goal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.lg,
          AppSpacing.screenGutter,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'History · ${goal.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(color: context.palette.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: GoalHistoryList(goal: goal, controller: controller),
            ),
          ],
        ),
      ),
    ),
  );
}

class GoalHistoryList extends ConsumerWidget {
  const GoalHistoryList({super.key, required this.goal, this.controller});

  final GoalEntity goal;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final finance = context.finance;
    final history = ref.watch(
      goalHistoryProvider((goalId: goal.id, currency: goal.currency)),
    );
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        text,
        style: AppTypography.body.copyWith(color: palette.muted),
      ),
    );

    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => hint(
        e is Failure ? e.message : 'History could not be loaded right now.',
      ),
      data: (h) {
        if (h.missing) return hint(kGoalHistoryMissingMessage);
        if (h.entries.isEmpty) return hint('No contributions recorded yet.');
        return ListView.separated(
          controller: controller,
          itemCount: h.entries.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = h.entries[i];
            final out = e.isWithdrawal;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _date.format(e.contributedAt),
                style: AppTypography.bodyStrong.copyWith(color: palette.ink),
              ),
              subtitle: e.note == null
                  ? null
                  : Text(
                      e.note!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(color: palette.muted),
                    ),
              trailing: Text(
                '${out ? '−' : '+'}${e.amount.abs.formatShort()}',
                style: AppTypography.bodyStrong.copyWith(
                  color: out ? finance.expense : finance.success,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
