import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/goal_editor_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_draft.dart';

/// Add funds to a goal, or take some back. The `goal_contribute` RPC owns the
/// limits (never below zero, never past target).
Future<void> openContributeSheet(BuildContext context, GoalEntity goal) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ContributeSheet(goal: goal),
  );
}

class _ContributeSheet extends ConsumerStatefulWidget {
  const _ContributeSheet({required this.goal});
  final GoalEntity goal;

  @override
  ConsumerState<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<_ContributeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _withdraw = false;
  bool _busy = false;
  Failure? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final magnitude = Money.tryParse(_amount.text)!.amount.abs().toDouble();
    final amount = _withdraw ? -magnitude : magnitude;

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(goalEditorControllerProvider)
          .contribute(widget.goal.id, amount);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_message(result))),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f;
      });
    }
  }

  String _message(GoalContribution r) {
    if (r.reached && r.capped) {
      return 'Goal reached — only ${r.applied.formatShort()} was needed.';
    }
    if (r.reached) return 'Goal reached 🎉';
    if (_withdraw) return '${r.applied.abs.formatShort()} taken back';
    return '${r.applied.formatShort()} added';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.goal.title, style: tt.titleLarge),
            Text(
              '${widget.goal.current.formatShort()} of '
              '${widget.goal.target.formatShort()} saved',
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Add')),
                ButtonSegment(value: true, label: Text('Take back')),
              ],
              selected: {_withdraw},
              onSelectionChanged: _busy
                  ? null
                  : (s) => setState(() => _withdraw = s.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: GoalValidators.contribution,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: AppRadius.field,
                ),
                child: Text(
                  _error!.message,
                  style: tt.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_withdraw ? 'Take back' : 'Add funds'),
            ),
          ],
        ),
      ),
    );
  }
}
