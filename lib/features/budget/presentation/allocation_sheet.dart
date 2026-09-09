import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/budget_editor_controller.dart';
import '../application/budget_providers.dart';
import '../domain/budget_buckets.dart';
import '../domain/budget_draft.dart';
import '../domain/budget_spend.dart';

/// Set (or clear) what a bucket is allocated this month.
Future<void> openAllocationSheet(BuildContext context, BudgetWithSpend b) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AllocationSheet(b: b),
  );
}

class _AllocationSheet extends ConsumerStatefulWidget {
  const _AllocationSheet({required this.b});
  final BudgetWithSpend b;

  @override
  ConsumerState<_AllocationSheet> createState() => _AllocationSheetState();
}

class _AllocationSheetState extends ConsumerState<_AllocationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  bool _busy = false;
  Failure? _error;

  bool get _hasExisting => !widget.b.budget.id.startsWith('unset:');

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: _hasExisting ? widget.b.budget.allocated.amount.toString() : '',
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
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
        _error = f;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final bucket = widget.b.budget.bucket;
    final period = ref.watch(budgetPeriodProvider);

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
            Text(bucket, style: tt.titleLarge),
            Text(
              'Monthly allocation',
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isNonExpenseBucket(bucket))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'This jar is money set aside, not spent — contributions show '
                  'up as goals, investments or transfers, so its tracked spend '
                  'stays at zero.',
                  style: tt.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
              validator: BudgetValidators.allocated,
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
              onPressed: _busy
                  ? null
                  : () {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      _run(
                        () => ref
                            .read(budgetEditorControllerProvider)
                            .setAllocation(
                              BudgetAllocationDraft(
                                bucket: bucket,
                                allocated: Money.tryParse(_amount.text)!,
                                periodStart: period,
                              ),
                            ),
                        'Budget saved',
                      );
                    },
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save allocation'),
            ),
            if (_hasExisting) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(budgetEditorControllerProvider)
                            .delete(widget.b.budget.id),
                        'Allocation removed',
                      ),
                child: const Text('Remove this allocation'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
