import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../application/reminders_editor_controller.dart';
import '../domain/reminder.dart';

Future<void> openReminderForm(
  BuildContext context, {
  Reminder? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReminderFormSheet(editing: editing),
  );
}

class _ReminderFormSheet extends ConsumerStatefulWidget {
  const _ReminderFormSheet({this.editing});
  final Reminder? editing;

  @override
  ConsumerState<_ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends ConsumerState<_ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  ReminderContext _context = ReminderContext.fixedDue;
  ReminderFrequency _frequency = ReminderFrequency.oneTime;
  late DateTime _dueDate;

  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _dueDate = e?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    if (e != null) {
      _title.text = e.title;
      _amount.text = e.amount?.amount.toString() ?? '';
      _notes.text = e.notes ?? '';
      _context = e.context;
      _frequency = e.frequency ?? ReminderFrequency.oneTime;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amountText = _amount.text.trim();
    final draft = ReminderDraft(
      title: _title.text,
      context: _context,
      dueDate: _dueDate,
      amount: amountText.isEmpty ? null : Money.tryParse(amountText),
      notes: _notes.text,
      frequency:
          _context == ReminderContext.fixedDue ? _frequency : null,
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(remindersEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!, draft);
      } else {
        await c.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Reminder updated' : 'Reminder scheduled'),
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
                _isEditing ? 'Edit reminder' : 'New reminder',
                style: AppTypography.title.copyWith(color: context.palette.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledField(
                label: 'Name',
                child: TextFormField(
                  controller: _title,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'e.g. HDFC credit card bill',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: ReminderValidators.title,
                ),
              ),
              LabeledField(
                label: 'Kind',
                child: DropdownButtonFormField<ReminderContext>(
                  initialValue: _context,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final c in ReminderContext.values)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c.label, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _context = v ?? _context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppSpacing.lg,
                  left: AppSpacing.xs,
                ),
                child: Text(
                  _context.hint,
                  style: tt.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: DateTimeField(
                  value: _dueDate,
                  showTime: false,
                  dateLabel: 'Target date',
                  firstDate: DateTime(DateTime.now().year - 1),
                  lastDate: DateTime(DateTime.now().year + 10),
                  onChanged: (v) => setState(() => _dueDate = v),
                ),
              ),
              if (_context == ReminderContext.fixedDue)
                LabeledField(
                  label: 'Repeat',
                  child: DropdownButtonFormField<ReminderFrequency>(
                    initialValue: _frequency,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: [
                      for (final f in ReminderFrequency.values)
                        DropdownMenuItem(value: f, child: Text(f.label)),
                    ],
                    onChanged: (v) =>
                        setState(() => _frequency = v ?? _frequency),
                  ),
                ),
              LabeledField(
                label: 'Amount (optional)',
                child: TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: ReminderValidators.amount,
                ),
              ),
              LabeledField(
                label: 'Note (optional)',
                child: TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'Anything to remember',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
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
                    : Text(_isEditing ? 'Save changes' : 'Schedule'),
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
