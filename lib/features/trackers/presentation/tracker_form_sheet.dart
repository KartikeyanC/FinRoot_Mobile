import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../application/tracker_editor_controller.dart';
import '../domain/tracker.dart';
import '../domain/tracker_draft.dart';

Future<void> openTrackerForm(BuildContext context, {TrackerEntity? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TrackerFormSheet(editing: editing),
  );
}

class _TrackerFormSheet extends ConsumerStatefulWidget {
  const _TrackerFormSheet({this.editing});
  final TrackerEntity? editing;

  @override
  ConsumerState<_TrackerFormSheet> createState() => _TrackerFormSheetState();
}

class _TrackerFormSheetState extends ConsumerState<_TrackerFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _budget = TextEditingController();
  final _description = TextEditingController();

  late String _type;
  late DateTime _startDate;
  DateTime? _endDate;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? 'Custom';
    _startDate = e?.startDate.toLocal() ?? DateTime.now();
    _endDate = e?.endDate?.toLocal();
    if (e != null) {
      _name.text = e.name;
      if (e.budget != null) _budget.text = e.budget!.amount.toString();
      _description.text = e.description ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? _startDate),
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 20),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final rangeError = TrackerValidators.dateRange(
      start: _startDate,
      end: _endDate,
    );
    if (rangeError != null) {
      setState(() => _error = ValidationFailure(rangeError));
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = TrackerDraft(
      name: _name.text,
      type: _type,
      startDate: _startDate,
      endDate: _endDate,
      budget: Money.tryParse(_budget.text),
      description: _description.text,
    );

    setState(() => _busy = true);
    try {
      final controller = ref.read(trackerEditorControllerProvider);
      if (_isEditing) {
        await controller.update(widget.editing!.id, draft);
      } else {
        await controller.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Tracker updated' : 'Tracker created'),
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
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xs,
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
                _isEditing ? 'Edit tracker' : 'New tracker',
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Name'),
              TextFormField(
                controller: _name,
                autofocus: !_isEditing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Dubai trip, Home build…',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: TrackerValidators.name,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Type'),
              DropdownButtonFormField<String>(
                initialValue: kTrackerTypes.contains(_type) ? _type : 'Custom',
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  for (final type in kTrackerTypes)
                    DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Icon(trackerTypeIcon(type), size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Text(type),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v ?? _type),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start',
                      value: RelativeTime.dayLabel(_startDate),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DateField(
                      label: 'End (optional)',
                      value: _endDate == null
                          ? 'Open'
                          : RelativeTime.dayLabel(_endDate!),
                      onTap: () => _pickDate(isStart: false),
                      onClear: _endDate == null
                          ? null
                          : () => setState(() => _endDate = null),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Budget (optional)'),
              TextFormField(
                controller: _budget,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: TrackerValidators.budget,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Description (optional)'),
              TextFormField(
                controller: _description,
                maxLength: 500,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What is this tracker for?',
                  prefixIcon: Icon(Icons.notes_rounded),
                  counterText: '',
                ),
                validator: TrackerValidators.description,
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
                    style: AppTypography.body.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Create tracker'),
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

/// 12px semibold muted label above a field.
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.label.copyWith(color: context.palette.muted),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(label),
        InkWell(
          onTap: onTap,
          borderRadius: AppRadius.field,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.event_outlined),
              suffixIcon: onClear == null
                  ? null
                  : IconButton(
                      tooltip: 'Clear date',
                      icon: const Icon(Icons.close),
                      onPressed: onClear,
                    ),
            ),
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }
}
