import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../accounts/presentation/wealth_kit.dart';
import 'domain/income_stream.dart';
import 'income_data.dart';

Future<void> openIncomeForm(
  BuildContext context, {
  required List<IncomeStream> existing,
  IncomeStream? editing,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _IncomeFormSheet(existing: existing, editing: editing),
);

class _IncomeFormSheet extends ConsumerStatefulWidget {
  const _IncomeFormSheet({required this.existing, this.editing});
  final List<IncomeStream> existing;
  final IncomeStream? editing;

  @override
  ConsumerState<_IncomeFormSheet> createState() => _IncomeFormSheetState();
}

class _IncomeFormSheetState extends ConsumerState<_IncomeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _rate = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String _type = 'active';
  String _category = kActiveIncomeCategories.first;
  String _currency = 'INR';
  String _frequency = 'monthly';
  String _icon = 'Briefcase';

  /// The person picked an icon; switching Active / Passive keeps it.
  bool _iconPicked = false;
  bool _recurring = true;
  DateTime? _nextDue;
  bool _busy = false;
  String? _error;

  IncomeStream? get _editing => widget.editing;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _name.text = e.name;
      _amount.text = _plain(e.amount);
      _rate.text = _plain(e.rate);
      _notes.text = e.notes ?? '';
      _type = e.type;
      _currency = kIncomeFx.containsKey(e.currency) ? e.currency : 'INR';
      _frequency = e.frequency;
      _icon = kIncomeIcons.containsKey(e.icon) ? e.icon : 'Coins';
    } else {
      final now = DateTime.now();
      _nextDue = DateTime(now.year, now.month, now.day);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _amount, _rate, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double _n(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  void _setType(String t) => setState(() {
    _type = t;
    final list = t == 'active'
        ? kActiveIncomeCategories
        : kPassiveIncomeCategories;
    if (!list.contains(_category)) _category = list.first;
    // A new stream follows the kind's usual icon until one is picked.
    if (_editing == null && !_iconPicked) {
      _icon = t == 'active' ? 'Briefcase' : 'Coins';
    }
  });

  void _setCurrency(String c) => setState(() {
    _currency = c;
    _rate.text = _plain(kIncomeFx[c] ?? 1);
  });

  IncomeStreamDraft _draft() => IncomeStreamDraft(
    name: _name.text.trim().isEmpty && _editing == null
        ? _category
        : _name.text,
    type: _type,
    amount: _n(_amount),
    currency: _currency,
    rate: _currency == 'INR' ? 1 : _n(_rate),
    frequency: _frequency,
    icon: _icon,
    notes: _notes.text,
  );

  Future<void> _run(
    Future<void> Function(IncomeEditor e) action,
    String done,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(incomeEditorProvider));
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
    final d = _draft();
    await _run(
      (ed) => e == null
          ? ed.add(
              d,
              existing: widget.existing,
              recurring: _recurring && _nextDue != null
                  ? (category: _category, nextDue: _nextDue!)
                  : null,
            )
          : ed.edit(e, d),
      e == null ? '${d.toRow()['name']} added' : 'Income stream updated',
    );
  }

  Future<void> _delete() async {
    final e = _editing!;
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${e.name}?',
      message:
          'It leaves the Income page here and on the web. Income already in '
          'your transactions and any recurring income stay.',
    );
    if (!ok || !mounted) return;
    await _run((ed) => ed.delete(e), 'Income stream deleted');
  }

  Widget _preview(BuildContext context) {
    final palette = context.palette;
    final amount = _n(_amount);
    final rate = _currency == 'INR' ? 1.0 : _n(_rate);
    if (amount <= 0 || rate <= 0) return const SizedBox.shrink();
    final stream = IncomeStream(
      id: '',
      name: '',
      type: _type,
      icon: _icon,
      amount: amount,
      currency: _currency,
      rate: rate,
      visible: true,
      order: 0,
      frequency: _frequency,
    );
    final String text;
    if (_frequency == 'one-time') {
      text = '${MoneyFormat.money(stream.inr)} once';
    } else if (_frequency == 'weekly') {
      text =
          '${MoneyFormat.money(stream.inr)} a week, about '
          '${MoneyFormat.money(stream.monthlyInr)} a month';
    } else {
      text = '${MoneyFormat.money(stream.monthlyInr)} a month';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        key: const ValueKey('income-preview'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.currency_rupee_rounded, color: palette.muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyStrong.copyWith(color: palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final editing = _editing != null;
    final categories = _type == 'active'
        ? kActiveIncomeCategories
        : kPassiveIncomeCategories;
    final now = DateTime.now();
    return SheetFrame(
      formKey: _formKey,
      title: editing ? 'Edit income' : 'Add income',
      subtitle: editing
          ? 'Change how this stream shows on the Income page.'
          : 'Salary, rent, dividends, freelance work… in rupees, dollars or '
                'euros.',
      primaryLabel: editing ? 'Save changes' : 'Add income',
      onPrimary: _submit,
      busy: _busy,
      error: _error,
      pinActions: true,
      extraActions: [
        if (editing)
          TextButton.icon(
            key: const ValueKey('income-delete'),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete stream'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
      children: [
        LabeledField(
          label: 'Kind',
          child: SegmentedButton<String>(
            key: const ValueKey('income-type'),
            segments: const [
              ButtonSegment(
                value: 'active',
                label: Text('Active'),
                icon: Icon(Icons.work_outline_rounded),
              ),
              ButtonSegment(
                value: 'passive',
                label: Text('Passive'),
                icon: Icon(Icons.savings_outlined),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (v) => _setType(v.first),
          ),
        ),
        if (!editing)
          LabeledField(
            label: 'Category',
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final c in categories)
                  ChoiceChip(
                    label: Text(c),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                  ),
              ],
            ),
          ),
        LabeledField(
          label: editing ? 'Name' : 'Name (optional)',
          child: TextFormField(
            key: const ValueKey('income-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: editing ? null : 'e.g. $_category from Acme',
              prefixIcon: const Icon(Icons.label_outline_rounded),
            ),
            validator: (v) {
              if (editing && (v?.trim() ?? '').isEmpty) return 'Name it';
              return IncomeValidators.name(v);
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: LabeledField(
                label: 'Amount',
                child: TextFormField(
                  key: const ValueKey('income-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '85000',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: IncomeValidators.amount,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: LabeledField(
                label: 'Currency',
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('income-currency'),
                  initialValue: _currency,
                  isExpanded: true,
                  items: [
                    for (final c in kIncomeFx.keys)
                      DropdownMenuItem(
                        value: c,
                        child: Text('${kIncomeCurrencySymbols[c]} $c'),
                      ),
                  ],
                  onChanged: (v) => _setCurrency(v ?? 'INR'),
                ),
              ),
            ),
          ],
        ),
        if (_currency != 'INR')
          LabeledField(
            label: 'Rupees per 1 $_currency',
            child: TextFormField(
              key: const ValueKey('income-rate'),
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.currency_exchange_rounded),
                helperText: 'Used to show this stream in rupees.',
              ),
              onChanged: (_) => setState(() {}),
              validator: IncomeValidators.rate,
            ),
          ),
        LabeledField(
          label: 'How often',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('income-frequency'),
            initialValue: _frequency,
            isExpanded: true,
            items: [
              for (final e in kIncomeFrequencies.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
          ),
        ),
        _preview(context),
        LabeledField(
          label: 'Icon',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final e in kIncomeIcons.entries)
                Semantics(
                  label: e.key,
                  selected: _icon == e.key,
                  button: true,
                  child: InkResponse(
                    onTap: () => setState(() {
                      _icon = e.key;
                      _iconPicked = true;
                    }),
                    radius: 24,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _icon == e.key
                            ? Tones.mint(context).bg
                            : palette.card,
                        border: Border.all(
                          color: _icon == e.key
                              ? Tones.mint(context).fg
                              : palette.line,
                          width: _icon == e.key ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        e.value,
                        size: 20,
                        color: _icon == e.key
                            ? Tones.mint(context).fg
                            : palette.muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!editing) ...[
          SwitchListTile(
            key: const ValueKey('income-recurring'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Also add to recurring income'),
            subtitle: const Text(
              'Get reminded when it is due and log it with one tap, as the '
              'web app does.',
            ),
            value: _recurring,
            onChanged: (v) => setState(() => _recurring = v),
          ),
          if (_recurring)
            DatePickField(
              key: const ValueKey('income-next-due'),
              label: _frequency == 'one-time'
                  ? 'Date you receive it'
                  : 'Next payment date',
              value: _nextDue,
              firstDate: DateTime(now.year - 2),
              lastDate: DateTime(now.year + 5),
              onChanged: (d) => setState(() => _nextDue = d),
            ),
        ],
        LabeledField(
          label: 'Notes (optional)',
          child: TextFormField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
