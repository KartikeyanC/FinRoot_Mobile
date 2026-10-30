import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../design/design.dart';
import '../application/recurring_editor_controller.dart';
import '../domain/recurring_item.dart';
import '../domain/reminder_setting.dart';

Future<void> openRecurringForm(
  BuildContext context, {
  RecurringItem? editing,
  RecurringType type = RecurringType.expense,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RecurringFormSheet(editing: editing, initialType: type),
  );
}

class _RecurringFormSheet extends ConsumerStatefulWidget {
  const _RecurringFormSheet({this.editing, required this.initialType});
  final RecurringItem? editing;
  final RecurringType initialType;

  @override
  ConsumerState<_RecurringFormSheet> createState() =>
      _RecurringFormSheetState();
}

class _RecurringFormSheetState extends ConsumerState<_RecurringFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  late RecurringType _type;
  late String _category;
  String _subtype = 'passive';
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  late DateTime _nextDue;

  bool _reminderOn = false;
  int _reminderDays = 3;

  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? widget.initialType;
    _category = e?.category ?? categoriesFor(_type).first;
    _subtype = e?.subtype ?? 'passive';
    _frequency = e?.frequency ?? RecurringFrequency.monthly;
    _nextDue = e?.nextDueDate ?? DateTime.now();
    if (e != null) {
      _name.text = e.name;
      _amount.text = e.amount.amount.toString();
      _notes.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setType(RecurringType type) {
    setState(() {
      _type = type;
      if (!categoriesFor(type).contains(_category)) {
        _category = categoriesFor(type).first;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = RecurringDraft(
      type: _type,
      name: _name.text,
      category: _category,
      amount: Money.tryParse(_amount.text)!,
      frequency: _frequency,
      nextDueDate: _nextDue,
      subtype: _type == RecurringType.income ? _subtype : null,
      notes: _notes.text,
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(recurringEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!.id, draft);
      } else {
        await c.create(
          draft,
          reminder: _reminderOn
              ? ReminderSetting(enabled: true, daysBefore: _reminderDays)
              : null,
        );
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Recurring item updated' : 'Recurring item added'),
        ),
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
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit recurring item' : 'New recurring item',
                style: AppTypography.title.copyWith(color: context.palette.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_isEditing)
                SegmentedButton<RecurringType>(
                  segments: const [
                    ButtonSegment(
                      value: RecurringType.income,
                      label: Text('Income'),
                    ),
                    ButtonSegment(
                      value: RecurringType.expense,
                      label: Text('Expense'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged:
                      _busy ? null : (s) => _setType(s.first),
                ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: _type == RecurringType.income
                      ? 'e.g. Salary — Acme'
                      : 'e.g. Apartment rent',
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                validator: RecurringValidators.name,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: [
                  for (final c in categoriesFor(_type))
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              if (_type == RecurringType.income) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _subtype,
                  decoration: const InputDecoration(
                    labelText: 'Subtype',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'passive', child: Text('Passive')),
                  ],
                  onChanged: (v) => setState(() => _subtype = v ?? _subtype),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: RecurringValidators.amount,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<RecurringFrequency>(
                initialValue: _frequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: [
                  for (final f in RecurringFrequency.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
              const SizedBox(height: AppSpacing.md),
              DateTimeField(
                value: _nextDue,
                showTime: false,
                dateLabel: 'Next due date',
                firstDate: DateTime(DateTime.now().year - 1),
                lastDate: DateTime(DateTime.now().year + 10),
                onChanged: (v) => setState(() => _nextDue = v),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
                validator: RecurringValidators.notes,
              ),
              if (!_isEditing) ...[
                const SizedBox(height: AppSpacing.xs),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Remind me before it is due'),
                  subtitle: _reminderOn
                      ? Text('$_reminderDays days before')
                      : const Text('Off — you can set this on the card later'),
                  value: _reminderOn,
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _reminderOn = v),
                ),
                if (_reminderOn)
                  DropdownButtonFormField<int>(
                    initialValue: _reminderDays,
                    decoration: const InputDecoration(
                      labelText: 'How early',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: [
                      for (final n in ReminderSetting.dayChoices)
                        DropdownMenuItem(
                          value: n,
                          child: Text('$n ${n == 1 ? 'day' : 'days'} before'),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _reminderDays = v ?? _reminderDays),
                  ),
              ],
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
                    : Text(_isEditing ? 'Save changes' : 'Add item'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
