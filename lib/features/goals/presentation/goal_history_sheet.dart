import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/currency.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/goal_editor_controller.dart';
import '../application/goals_providers.dart';
import '../domain/goal.dart';
import '../domain/goal_history.dart';

final _date = DateFormat('d MMM yyyy');

/// A goal's contribution history (date, amount, note), newest first — the same
/// `goal_contributions` rows the web shows. Tap an entry to change its amount,
/// note or date, or to delete it (migration 20261126160000): the goal's saved
/// amount moves by the same difference, so the list keeps adding up to what
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
    // The goal as it is now: an edit moves its saved amount.
    final live = ref.watch(goalByIdProvider(goal.id)).value ?? goal;
    final canEdit =
        (ref.watch(currentRoleProvider)?.canWrite ?? true) &&
        ref.watch(isOnlineProvider);
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
          itemCount: h.entries.length + (canEdit ? 1 : 0),
          separatorBuilder: (_, i) => canEdit && i == 0
              ? const SizedBox.shrink()
              : const Divider(height: 1),
          itemBuilder: (context, i) {
            if (canEdit && i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  'Tap an entry to change or delete it.',
                  style: AppTypography.caption.copyWith(color: palette.muted),
                ),
              );
            }
            final e = h.entries[i - (canEdit ? 1 : 0)];
            final out = e.isWithdrawal;
            return ListTile(
              key: ValueKey('goal-history-${e.id}'),
              contentPadding: EdgeInsets.zero,
              onTap: canEdit
                  ? () => openGoalHistoryEntrySheet(context, live, e)
                  : null,
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

/// Change or delete one history entry.
Future<void> openGoalHistoryEntrySheet(
  BuildContext context,
  GoalEntity goal,
  GoalContributionEntry entry,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => GoalHistoryEntrySheet(goal: goal, entry: entry),
  );
}

class GoalHistoryEntrySheet extends ConsumerStatefulWidget {
  const GoalHistoryEntrySheet({
    super.key,
    required this.goal,
    required this.entry,
  });

  final GoalEntity goal;
  final GoalContributionEntry entry;

  @override
  ConsumerState<GoalHistoryEntrySheet> createState() =>
      _GoalHistoryEntrySheetState();
}

class _GoalHistoryEntrySheetState extends ConsumerState<GoalHistoryEntrySheet> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late bool _takeBack;
  late DateTime _date;
  bool _busy = false;
  String? _error;

  double get _original => widget.entry.amount.amount.toDouble();

  @override
  void initState() {
    super.initState();
    final a = _original.abs();
    _amount = TextEditingController(
      text: a == a.roundToDouble() ? a.toStringAsFixed(0) : a.toString(),
    );
    _note = TextEditingController(text: widget.entry.note ?? '');
    _takeBack = widget.entry.isWithdrawal;
    _date = DateUtils.dateOnly(widget.entry.contributedAt);
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _next {
    final n = double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    return _takeBack ? -n : n;
  }

  String? _problem({bool deleting = false}) => historyChangeProblem(
    original: _original,
    next: deleting ? 0 : _next,
    deleting: deleting,
    currentAmount: widget.goal.current.amount.toDouble(),
    targetAmount: widget.goal.target.amount.toDouble(),
    date: deleting ? null : _date,
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.message;
      });
    }
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    await _run(
      () => ref
          .read(goalEditorControllerProvider)
          .editContribution(
            widget.goal.id,
            widget.entry.id,
            _next,
            note: _note.text,
            date: _date,
          ),
      'History updated',
    );
  }

  Future<void> _delete() async {
    final problem = _problem(deleting: true);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final out = widget.entry.isWithdrawal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          'The goal ${out ? 'gets back' : 'loses'} '
          '${widget.entry.amount.abs.format()}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(
      () => ref
          .read(goalEditorControllerProvider)
          .deleteContribution(widget.goal.id, widget.entry.id),
      'Entry deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final symbol = currencySymbol(widget.goal.currency);
    final problem = _problem();
    final ml = MaterialLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit history entry',
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Added')),
                ButtonSegment(value: true, label: Text('Taken back')),
              ],
              selected: {_takeBack},
              onSelectionChanged: (s) => setState(() => _takeBack = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('goal-history-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: symbol.isEmpty
                    ? '${widget.goal.currency} '
                    : '$symbol ',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date'),
                child: Text(ml.formatMediumDate(_date)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('goal-history-note'),
              controller: _note,
              maxLength: kGoalNoteMax,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if ((_error ?? problem) != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                (_error ?? problem)!,
                style: AppTypography.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            PillButton(
              label: _busy ? 'Saving…' : 'Save changes',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _busy || problem != null ? null : _save,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              key: const Key('goal-history-delete'),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete entry'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
