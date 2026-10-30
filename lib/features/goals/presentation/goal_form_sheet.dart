import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../application/goal_editor_controller.dart';
import '../domain/goal.dart';
import '../domain/goal_draft.dart';

Future<void> openGoalForm(BuildContext context, {GoalEntity? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _GoalFormSheet(editing: editing),
  );
}

class _GoalFormSheet extends ConsumerStatefulWidget {
  const _GoalFormSheet({this.editing});
  final GoalEntity? editing;

  @override
  ConsumerState<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends ConsumerState<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _target = TextEditingController();
  String? _category;
  DateTime? _targetDate;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final g = widget.editing;
    if (g != null) {
      _title.text = g.title;
      _target.text = g.target.amount.toString();
      _category = g.category;
      _targetDate = g.targetDate?.toLocal();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = GoalDraft(
      title: _title.text,
      target: Money.tryParse(_target.text)!,
      category: _category,
      targetDate: _targetDate,
    );

    setState(() => _busy = true);
    try {
      final controller = ref.read(goalEditorControllerProvider);
      if (_isEditing) {
        await controller.update(widget.editing!.id, draft);
      } else {
        await controller.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Goal updated' : 'Goal added')),
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
      title: _isEditing ? 'Edit goal' : 'New goal',
      primaryLabel: _isEditing ? 'Save changes' : 'Add goal',
      onPrimary: _submit,
      busy: _busy,
      error: _error?.message,
      children: [
        LabeledField(
          label: 'What are you saving for?',
          child: TextFormField(
            controller: _title,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Emergency fund',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            validator: GoalValidators.title,
          ),
        ),
        LabeledField(
          label: 'Target amount',
          child: TextFormField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: GoalValidators.target,
          ),
        ),
        LabeledField(
          label: 'Category (optional)',
          child: DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(child: Text('Not set')),
              for (final c in kGoalCategories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
        ),
        LabeledField(
          label: 'Target date (optional)',
          child: InkWell(
            onTap: () async {
              FocusScope.of(context).unfocus();
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 30),
              );
              if (picked != null) setState(() => _targetDate = picked);
            },
            borderRadius: AppRadius.field,
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: _targetDate == null
                    ? null
                    : IconButton(
                        tooltip: 'Clear target date',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _targetDate = null),
                      ),
              ),
              child: Text(
                _targetDate == null
                    ? 'No date'
                    : RelativeTime.dayLabel(_targetDate!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
