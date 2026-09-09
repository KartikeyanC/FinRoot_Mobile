import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../application/recurring_editor_controller.dart';
import '../application/recurring_providers.dart';
import '../domain/reminder_setting.dart';

/// The "bell" on a recurring card — opens a sheet to set / clear the per-item
/// reminder (`recurring_reminders`). Drives the on-device notification for
/// that item.
class ReminderBell extends ConsumerWidget {
  const ReminderBell({super.key, required this.itemId, required this.dueDate});

  final String itemId;
  final DateTime dueDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setting = ref.watch(reminderSettingForProvider(itemId));
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: setting.enabled
          ? 'Reminder: ${setting.daysBefore}d before'
          : 'Set a reminder',
      icon: Icon(
        setting.enabled
            ? Icons.notifications_active
            : Icons.notifications_none,
        size: 20,
        color: setting.enabled ? scheme.primary : scheme.onSurfaceVariant,
      ),
      onPressed: () => _open(context, ref, setting),
    );
  }

  void _open(BuildContext context, WidgetRef ref, ReminderSetting current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReminderSheet(itemId: itemId, current: current),
    );
  }
}

class _ReminderSheet extends ConsumerStatefulWidget {
  const _ReminderSheet({required this.itemId, required this.current});
  final String itemId;
  final ReminderSetting current;

  @override
  ConsumerState<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends ConsumerState<_ReminderSheet> {
  late bool _enabled;
  late int _daysBefore;
  late final TextEditingController _note;
  bool _busy = false;
  Failure? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.current.enabled;
    _daysBefore = widget.current.daysBefore;
    _note = TextEditingController(text: widget.current.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = ref.read(recurringEditorControllerProvider);
      if (_enabled) {
        await c.saveReminder(
          widget.itemId,
          ReminderSetting(
            enabled: true,
            daysBefore: _daysBefore,
            note: _note.text.trim(),
          ),
        );
      } else {
        await c.removeReminder(widget.itemId);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_enabled ? 'Reminder set' : 'Reminder cleared')),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reminder', style: tt.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Get a notification before this item is due.',
            style: tt.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Remind me'),
            value: _enabled,
            onChanged: _busy ? null : (v) => setState(() => _enabled = v),
          ),
          if (_enabled) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              initialValue: _daysBefore,
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
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _daysBefore = v ?? _daysBefore),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. check the bank balance first',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!.message,
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
