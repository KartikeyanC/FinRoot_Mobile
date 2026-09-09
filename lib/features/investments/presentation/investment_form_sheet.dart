import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/investment_editor_controller.dart';
import '../domain/investment.dart';

Future<void> openInvestmentForm(
  BuildContext context, {
  InvestmentRecord? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _InvestmentFormSheet(editing: editing),
  );
}

class _InvestmentFormSheet extends ConsumerStatefulWidget {
  const _InvestmentFormSheet({this.editing});
  final InvestmentRecord? editing;

  @override
  ConsumerState<_InvestmentFormSheet> createState() =>
      _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<_InvestmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _invested = TextEditingController();
  final _current = TextEditingController();
  late String _asset;
  String? _goal;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _asset = e?.asset ?? 'stocks';
    if (e != null) {
      _name.text = e.name;
      _invested.text = e.invested.amount.toString();
      _current.text = e.current.amount.toString();
      _goal = e.goal;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _invested.dispose();
    _current.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = InvestmentDraft(
      asset: _asset,
      name: _name.text,
      invested: Money.tryParse(_invested.text)!,
      current: Money.tryParse(_current.text)!,
      goal: _goal,
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(investmentEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!.id, draft);
      } else {
        await c.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Holding updated' : 'Holding added')),
      );
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit holding' : 'Add holding',
                style: tt.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'A simple invested / current value. The web app keeps the '
                'detailed per-asset calculators.',
                style: tt.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: _asset,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Asset type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final a in kAssetTypes)
                    DropdownMenuItem(
                      value: a,
                      child: Row(
                        children: [
                          Icon(assetIcon(a), size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(assetLabel(a)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _asset = v ?? _asset),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: InvestmentValidators.name,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _invested,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount invested',
                  prefixIcon: Icon(Icons.south_west_rounded),
                ),
                validator: (v) =>
                    InvestmentValidators.amount(v, label: 'the amount invested'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _current,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Current value',
                  prefixIcon: Icon(Icons.trending_up),
                ),
                validator: (v) =>
                    InvestmentValidators.amount(v, label: 'the current value'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _goal,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Goal link (optional)',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(child: Text('Not set')),
                  for (final g in kInvestmentGoals)
                    DropdownMenuItem(value: g, child: Text(g)),
                ],
                onChanged: (v) => setState(() => _goal = v),
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
                    : Text(_isEditing ? 'Save changes' : 'Add holding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
