import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/goal_editor_controller.dart';
import '../application/goals_providers.dart';
import '../domain/goal.dart';
import 'contribute_sheet.dart';
import 'goal_form_sheet.dart';

/// Goals (M10) — savings targets. Menu-gated (ADR-0002). Contributions go
/// through the `goal_contribute` RPC.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.goals)) == MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Goals',
        body: MenuLockedView(feature: 'Goals', icon: Icons.flag_outlined),
      );
    }

    final goals = ref.watch(goalsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasGoals = goals.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Goals',
      padBody: false,
      floatingActionButton: canWrite && hasGoals
          ? AddFab(label: 'Goal', onPressed: () => openGoalForm(context))
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: goals.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) => list.isEmpty
              ? _Empty(canWrite: canWrite)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.xs,
                    AppSpacing.screenGutter,
                    96,
                  ),
                  children: [
                    _Summary(goals: list),
                    const SizedBox(height: AppSpacing.lg),
                    for (var i = 0; i < list.length; i++)
                      _GoalCard(goal: list[i], index: i, canWrite: canWrite),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.goals});
  final List<GoalEntity> goals;

  @override
  Widget build(BuildContext context) {
    final reached = goals.where((g) => g.isComplete).length;
    final saved = goals.fold(Money.zero(), (s, g) => s + g.current);
    return StatStrip([
      Stat('${goals.length - reached}', 'Active'),
      Stat('$reached', 'Completed', color: context.finance.success),
      Stat(saved.formatShort(), 'Saved'),
    ]);
  }
}

IconData _iconFor(String? category) => switch (category) {
  'Emergency Fund' => Icons.shield_outlined,
  'Insurance' => Icons.health_and_safety_outlined,
  'Travel' => Icons.flight_takeoff_rounded,
  'Education' => Icons.school_outlined,
  'Vehicle' => Icons.directions_car_outlined,
  'Home' => Icons.home_outlined,
  'Retirement' => Icons.beach_access_outlined,
  'Gadget' => Icons.devices_other_outlined,
  _ => Icons.flag_outlined,
};

/// On track / Behind / Reached. There is no start date to measure pace against,
/// so "behind" means: the date has passed, or it is close and under half done.
({String label, Tone tone}) _status(BuildContext c, GoalEntity g) {
  if (g.isComplete) return (label: 'Reached', tone: Tones.mint(c));
  final date = g.targetDate;
  if (date != null) {
    final days = date.toLocal().difference(DateTime.now()).inDays;
    if (days < 0 || (days < 60 && g.progress < 0.5)) {
      return (label: 'Behind', tone: Tones.coral(c));
    }
  }
  return (label: 'On track', tone: Tones.sky(c));
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.index,
    required this.canWrite,
  });
  final GoalEntity goal;
  final int index;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final finance = context.finance;
    final status = _status(context, goal);
    final tone = goal.isComplete
        ? Tones.mint(context)
        : Tones.byIndex(context, index);
    final barColor = goal.isComplete
        ? finance.success
        : (status.label == 'Behind' ? finance.warning : tone.fg);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ToneTile(icon: _iconFor(goal.category), tone: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        goal.targetDate != null
                            ? 'by ${RelativeTime.dayLabel(goal.targetDate!)}'
                            : 'No target date',
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
                TonePill(status.label, status.tone),
                if (!goal.isComplete && canWrite)
                  RowMenu(
                    onSelected: (v) => _onAction(context, ref, v),
                    items: const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: goal.current.formatShort(),
                      style: AppTypography.title.copyWith(
                        color: palette.ink,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      children: [
                        TextSpan(
                          text: '  of ${goal.target.formatShort()}',
                          style: AppTypography.body.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${goal.progressPercent}%',
                  style: AppTypography.bodyStrong.copyWith(color: barColor),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SlimBar(value: goal.progress, color: barColor),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.isComplete
                        ? 'Target met'
                        : '${goal.remaining.formatShort()} to go',
                    style: AppTypography.label.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (canWrite)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => openContributeSheet(context, goal),
                    child: Text(goal.isComplete ? 'Adjust' : 'Add funds'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'edit') {
      await openGoalForm(context, editing: goal);
      return;
    }
    if (action == 'delete') {
      final ok = await confirmDestructive(
        context,
        title: 'Delete "${goal.title}"?',
        message: 'This does not touch any account balance.',
      );
      if (!ok) return;
      try {
        await ref.read(goalEditorControllerProvider).delete(goal.id);
        messenger.showSnackBar(const SnackBar(content: Text('Goal deleted')));
      } on Failure catch (f) {
        messenger.showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.flag_outlined,
      title: 'No goals yet',
      message:
          'Set a target — an emergency fund, a trip, a deposit — and add to '
          'it over time.',
      action: canWrite
          ? FilledButton(
              onPressed: () => openGoalForm(context),
              child: const Text('Add a goal'),
            )
          : null,
    );
  }
}
