import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
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
    return SheetFrame(
      formKey: _formKey,
      title: _isEditing ? 'Edit holding' : 'Add holding',
      subtitle:
          'A simple invested / current value. The web app keeps the '
          'detailed per-asset calculators.',
      primaryLabel: _isEditing ? 'Save changes' : 'Add holding',
      onPrimary: _submit,
      busy: _busy,
      error: _error?.message,
      children: [
        LabeledField(
          label: 'Asset type',
          child: DropdownButtonFormField<String>(
            initialValue: _asset,
            isExpanded: true,
            decoration: const InputDecoration(
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
                      Flexible(
                        child: Text(
                          assetLabel(a),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _asset = v ?? _asset),
          ),
        ),
        LabeledField(
          label: 'Name',
          child: TextFormField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'ITC, Nifty 50 fund…',
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: InvestmentValidators.name,
          ),
        ),
        LabeledField(
          label: 'Amount invested',
          child: TextFormField(
            controller: _invested,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.south_west_rounded),
            ),
            validator: (v) =>
                InvestmentValidators.amount(v, label: 'the amount invested'),
          ),
        ),
        LabeledField(
          label: 'Current value',
          child: TextFormField(
            controller: _current,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.trending_up),
            ),
            validator: (v) =>
                InvestmentValidators.amount(v, label: 'the current value'),
          ),
        ),
        LabeledField(
          label: 'Goal link (optional)',
          child: DropdownButtonFormField<String>(
            initialValue: _goal,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(child: Text('Not set')),
              for (final g in kInvestmentGoals)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _goal = v),
          ),
        ),
      ],
    );
  }
}
