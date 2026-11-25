import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../design/design.dart';
import '../accounts/presentation/wealth_kit.dart';
import 'subscriptions.dart';

Future<void> openSubscriptionForm(
  BuildContext context, {
  TrackedSubscription? editing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _SubscriptionFormSheet(editing: editing),
);

/// Emoji the picker offers; any other can be typed.
const _icons = ['💳', '📺', '🎵', '☁️', '🎮', '💪', '📰', '📱', '🛒', '🚗'];

/// The billing cycles offered: key → (stored frequency, months per bill,
/// label). "Custom" asks for the number of months.
const _cycles = <String, (String, int, String)>{
  'weekly': ('weekly', 1, 'Weekly'),
  'monthly': ('monthly', 1, 'Monthly'),
  'quarterly': ('monthly', 3, 'Every 3 months'),
  'half-yearly': ('monthly', 6, 'Every 6 months'),
  'annual': ('annual', 1, 'Yearly'),
  'custom': ('monthly', 0, 'Custom…'),
};

String _cycleOf(String frequency, int months) {
  if (frequency == 'weekly') return 'weekly';
  if (frequency == 'annual') return 'annual';
  return switch (months) {
    1 => 'monthly',
    3 => 'quarterly',
    6 => 'half-yearly',
    _ => 'custom',
  };
}

class _SubscriptionFormSheet extends ConsumerStatefulWidget {
  const _SubscriptionFormSheet({this.editing});
  final TrackedSubscription? editing;

  @override
  ConsumerState<_SubscriptionFormSheet> createState() =>
      _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState
    extends ConsumerState<_SubscriptionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _icon = TextEditingController(text: '💳');
  final _months = TextEditingController(text: '2');
  String _cycle = 'monthly';
  DateTime? _renewal;
  bool _busy = false;
  String? _error;

  TrackedSubscription? get _editing => widget.editing;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _name.text = e.name;
      _amount.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toInt().toString()
          : e.amount.toString();
      if (e.icon != null && e.icon!.isNotEmpty) _icon.text = e.icon!;
      _cycle = _cycleOf(e.frequency, e.intervalMonths);
      if (_cycle == 'custom') _months.text = '${e.intervalMonths}';
      _renewal = e.renewal;
    } else {
      final now = DateTime.now();
      _renewal = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _icon.dispose();
    _months.dispose();
    super.dispose();
  }

  String get _frequency => _cycles[_cycle]!.$1;

  int get _intervalMonths {
    final c = _cycles[_cycle]!;
    if (_cycle != 'custom') return c.$2;
    return int.tryParse(_months.text.trim()) ?? 1;
  }

  SubscriptionDraft _draft() => SubscriptionDraft(
    name: _name.text,
    icon: _icon.text,
    amount: double.parse(_amount.text.replaceAll(',', '').trim()),
    frequency: _frequency,
    intervalMonths: _intervalMonths,
    renewal: _renewal!,
  );

  Future<void> _run(
    Future<void> Function(SubscriptionEditor e) action,
    String done,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(subscriptionEditorProvider));
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final e = _editing;
    await _run(
      (ed) => e == null ? ed.add(_draft()) : ed.edit(e, _draft()),
      e == null ? 'Subscription added' : 'Subscription updated',
    );
  }

  Future<void> _delete() async {
    final e = _editing!;
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${e.name}?',
      message:
          'It stops being tracked here and on the web. Payments already in '
          'your transactions stay.',
    );
    if (!ok || !mounted) return;
    await _run((ed) => ed.delete(e), 'Subscription deleted');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final editing = _editing != null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final passed = _renewal != null && _renewal!.isBefore(today);
    final caughtUp = passed
        ? catchUpRenewal(
            _renewal!,
            _frequency,
            today,
            intervalMonths: _intervalMonths < 1 ? 1 : _intervalMonths,
          )
        : null;

    return SheetFrame(
      formKey: _formKey,
      title: editing ? 'Edit subscription' : 'Add a subscription',
      subtitle: 'A service you pay for regularly: streaming, cloud, gym…',
      primaryLabel: editing ? 'Save changes' : 'Add subscription',
      onPrimary: _submit,
      busy: _busy,
      error: _error,
      pinActions: true,
      extraActions: [
        if (editing)
          TextButton.icon(
            key: const ValueKey('sub-delete'),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete subscription'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
      children: [
        LabeledField(
          label: 'Service',
          child: TextFormField(
            key: const ValueKey('sub-name'),
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Netflix, Spotify, iCloud…',
              prefixIcon: Icon(Icons.subscriptions_outlined),
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Name the service';
              if (t.length > 60) return 'That name is too long';
              return null;
            },
          ),
        ),
        LabeledField(
          label: 'Icon',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final i in _icons)
                ChoiceChip(
                  label: Text(i, style: const TextStyle(fontSize: 18)),
                  selected: _icon.text == i,
                  onSelected: (_) => setState(() => _icon.text = i),
                ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Amount',
                child: TextFormField(
                  key: const ValueKey('sub-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '649',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (v) {
                    final n = double.tryParse(
                      (v ?? '').replaceAll(',', '').trim(),
                    );
                    if (n == null || !n.isFinite || n <= 0) {
                      return 'Enter the amount';
                    }
                    if (n > 99999999) return 'That amount is too large';
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: 'Billed',
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('sub-frequency'),
                  initialValue: _cycle,
                  isExpanded: true,
                  items: [
                    for (final e in _cycles.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value.$3)),
                  ],
                  onChanged: (v) => setState(() => _cycle = v ?? 'monthly'),
                ),
              ),
            ),
          ],
        ),
        if (_cycle == 'custom')
          LabeledField(
            label: 'Every how many months?',
            child: TextFormField(
              key: const ValueKey('sub-months'),
              controller: _months,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '2',
                suffixText: 'months',
                prefixIcon: Icon(Icons.event_repeat_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 2 || n > 60) {
                  return 'Between 2 and 60 months';
                }
                return null;
              },
            ),
          ),
        DatePickField(
          key: const ValueKey('sub-renewal'),
          label: 'Next renewal',
          value: _renewal,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 10),
          onChanged: (d) => setState(() => _renewal = d),
          validator: (_) => _renewal == null ? 'Pick the renewal date' : null,
        ),
        if (caughtUp != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.update_rounded, color: palette.muted),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'That date has passed. Renewed already?',
                          style: AppTypography.body.copyWith(
                            color: palette.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('sub-catch-up'),
                      onPressed: () => setState(() => _renewal = caughtUp),
                      child: Text(
                        'Move to ${DateFormat('d MMM yyyy').format(caughtUp)}',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
