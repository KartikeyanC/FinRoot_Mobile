import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
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
      return Scaffold(
        appBar: AppBar(title: const Text('Goals')),
        body: const MenuLockedView(feature: 'Goals', icon: Icons.flag_outlined),
      );
    }

    final goals = ref.watch(goalsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: canWrite
          ? GradientExtendedFab(
              onPressed: () => openGoalForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Goal'),
            )
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
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.huge,
                  ),
                  children: [
                    for (final g in list)
                      _GoalCard(goal: g, canWrite: canWrite),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.canWrite});
  final GoalEntity goal;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium,
                  ),
                ),
                if (goal.isComplete)
                  Icon(Icons.check_circle, size: 18, color: finance.success)
                else if (canWrite)
                  PopupMenuButton<String>(
                    onSelected: (v) => _onAction(context, ref, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                AmountText.money(goal.current, signed: false),
                Text(
                  ' of ${goal.target.formatShort()}',
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text('${goal.progressPercent}%', style: tt.labelMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(
                  goal.isComplete ? finance.success : scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(
                  goal.isComplete
                      ? 'Reached'
                      : '${goal.remaining.formatShort()} to go',
                  style: tt.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (goal.targetDate != null) ...[
                  Text(
                    '  ·  by ${RelativeTime.dayLabel(goal.targetDate!)}',
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const Spacer(),
                if (canWrite && !goal.isComplete)
                  TextButton(
                    onPressed: () => openContributeSheet(context, goal),
                    child: const Text('Add funds'),
                  )
                else if (canWrite)
                  TextButton(
                    onPressed: () => openContributeSheet(context, goal),
                    child: const Text('Adjust'),
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
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete "${goal.title}"?'),
          content: const Text('This does not touch any account balance.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: AppButtonStyles.destructive,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (ok != true) return;
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
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyView(
          icon: Icons.flag_outlined,
          title: 'No goals yet',
          message:
              'Set a target — an emergency fund, a trip, a deposit — and add '
              'to it over time.',
          action: canWrite
              ? FilledButton(
                  onPressed: () => openGoalForm(context),
                  child: const Text('Add a goal'),
                )
              : null,
        ),
      ],
    );
  }
}
