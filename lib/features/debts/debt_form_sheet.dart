import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
import '../accounts/presentation/wealth_kit.dart';
import 'debt_editor.dart';
import 'debt_plan.dart';
import 'debts.dart';

Future<void> openDebtForm(BuildContext context, {Debt? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _DebtFormSheet(editing: editing),
    );

class _DebtFormSheet extends ConsumerStatefulWidget {
  const _DebtFormSheet({this.editing});
  final Debt? editing;

  @override
  ConsumerState<_DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<_DebtFormSheet> {
  static const _quickMonths = [3, 6, 12, 24, 36];

  final _formKey = GlobalKey<FormState>();
  final _lender = TextEditingController();
  final _total = TextEditingController();
  final _emi = TextEditingController();
  final _months = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Other';
  DateTime? _firstDue;

  /// The person knows their EMI, not the total: total = EMI × months.
  bool _byEmi = false;

  /// How many EMIs were paid before the loan was added (null = the number
  /// of due dates already past).
  int? _paidBeforeChoice;
  bool _busy = false;
  String? _error;

  Debt? get _editing => widget.editing;

  /// Paid EMIs fix the schedule.
  bool get _locked => (_editing?.paidCount ?? 0) > 0;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _lender.text = e.lender;
      _total.text = _plain(e.total);
      _months.text = '${e.duration}';
      _notes.text = e.notes ?? '';
      if (e.category.isNotEmpty) _category = e.category;
      _firstDue = e.firstDue ?? e.installments.firstOrNull?.dueDate;
    } else {
      final now = DateTime.now();
      _firstDue = DateTime(now.year, now.month + 1, 5);
      _months.text = '12';
    }
  }

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _lender.dispose();
    _total.dispose();
    _emi.dispose();
    _months.dispose();
    _notes.dispose();
    super.dispose();
  }

  static double _number(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  double get _totalValue => _byEmi
      ? ((_number(_emi) * _monthsValue) * 100).roundToDouble() / 100
      : _number(_total);
  int get _monthsValue => int.tryParse(_months.text.trim()) ?? 0;

  /// EMIs whose date passed before today — offered as already paid when a
  /// loan is added part-way through.
  int get _pastDue {
    final first = _firstDue;
    if (_editing != null || first == null || _monthsValue < 1) return 0;
    return emisDueBefore(first, _monthsValue, DateTime.now());
  }

  int get _paidBefore {
    final n = _paidBeforeChoice ?? _pastDue;
    return n.clamp(0, _monthsValue < 0 ? 0 : _monthsValue);
  }

  DebtDraft _draft() => DebtDraft(
    lender: _lender.text,
    category: _category,
    total: _totalValue,
    months: _monthsValue,
    firstDue: _firstDue!,
    notes: _notes.text,
    currency: _editing?.currency ?? 'INR',
    paidBefore: _editing == null ? _paidBefore : 0,
  );

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final editor = ref.read(debtEditorProvider);
      if (_editing != null) {
        await editor.edit(_editing!, _draft());
      } else {
        await editor.add(_draft());
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editing != null
                ? 'Debt updated'
                : _paidBefore > 0
                ? 'Debt added · $_paidBefore EMIs already paid, '
                      '${_monthsValue - _paidBefore} to go'
                : 'Debt added · $_monthsValue EMIs scheduled',
          ),
        ),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.message;
      });
    }
  }

  Future<void> _delete() async {
    final e = _editing!;
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${e.lender}?',
      message:
          'The debt and its upcoming EMI reminders are removed. Paid EMIs '
          'already in your transactions stay. This can\'t be undone.',
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(debtEditorProvider).delete(e);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Debt deleted')));
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.message;
      });
    }
  }

  Widget _preview(BuildContext context) {
    final palette = context.palette;
    final months = _monthsValue;
    final total = _totalValue;
    final first = _firstDue;
    if (total <= 0 || months < 1 || first == null) {
      return const SizedBox.shrink();
    }
    final monthly = computeMonthly(total, months);
    final last = emiDate(first, months - 1);
    final paid = _paidBefore;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        key: const ValueKey('debt-preview'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded, color: palette.muted),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${MoneyFormat.money(monthly)} a month',
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    '$months EMIs · last on '
                    '${DateFormat('d MMM yyyy').format(last)}',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                  if (paid > 0)
                    Text(
                      '$paid already paid · '
                      '${MoneyFormat.money(total - monthly * paid)} left',
                      style: AppTypography.label.copyWith(color: palette.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "EMIs already paid": for a loan that began before it was added here.
  Widget _paidBeforeField(BuildContext context) {
    final palette = context.palette;
    final n = _paidBefore;
    final months = _monthsValue;
    void set(int v) => setState(() => _paidBeforeChoice = v.clamp(0, months));
    return LabeledField(
      label: 'EMIs already paid before today',
      child: Container(
        key: const ValueKey('debt-paid-before'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('debt-paid-before-less'),
              tooltip: 'One fewer',
              onPressed: n > 0 ? () => set(n - 1) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '$n of $months',
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    n == 0
                        ? 'None ticked off'
                        : 'Marked paid on their due dates',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('debt-paid-before-more'),
              tooltip: 'One more',
              onPressed: n < months ? () => set(n + 1) : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing != null;
    final categories = {...kExpenseCategories, _category}.toList();
    final now = DateTime.now();
    return SheetFrame(
      formKey: _formKey,
      title: editing ? 'Edit debt' : 'Add a debt',
      subtitle: editing
          ? (_locked
                ? '${_editing!.paidCount} of ${_editing!.duration} EMIs are '
                      'paid, so the total and dates are fixed. To change one '
                      'EMI\'s amount, open the loan\'s EMI list.'
                : 'Change the details or the EMI schedule.')
          : 'A loan or EMI plan. FinRoot splits it into monthly EMIs and '
                'reminds you before each one.',
      primaryLabel: editing ? 'Save changes' : 'Add debt',
      onPrimary: _submit,
      busy: _busy,
      error: _error,
      pinActions: true,
      extraActions: [
        if (editing)
          TextButton.icon(
            key: const ValueKey('debt-delete'),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete debt'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
      children: [
        LabeledField(
          label: 'Lender',
          child: TextFormField(
            key: const ValueKey('debt-lender'),
            controller: _lender,
            autofocus: !editing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'HDFC Bank, Bajaj Finserv, Rahul…',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            validator: DebtValidators.lender,
          ),
        ),
        if (!_locked)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: SegmentedButton<bool>(
              key: const ValueKey('debt-amount-mode'),
              segments: const [
                ButtonSegment(value: false, label: Text('Total amount')),
                ButtonSegment(value: true, label: Text('EMI amount')),
              ],
              selected: {_byEmi},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() {
                _byEmi = v.first;
                // Carry the figure across so switching loses nothing.
                final months = _monthsValue;
                if (_byEmi && _number(_total) > 0 && months > 0) {
                  _emi.text = _plain(
                    (_number(_total) / months * 100).roundToDouble() / 100,
                  );
                } else if (!_byEmi && _number(_emi) > 0 && months > 0) {
                  _total.text = _plain(_number(_emi) * months);
                }
              }),
            ),
          ),
        if (_byEmi && !_locked)
          LabeledField(
            label: 'EMI amount (each month)',
            child: TextFormField(
              key: const ValueKey('debt-emi'),
              controller: _emi,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '2500',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) => DebtValidators.total(v) == null
                  ? null
                  : 'Enter the EMI amount',
            ),
          )
        else
          LabeledField(
            label: 'Total to repay',
            child: TextFormField(
              key: const ValueKey('debt-total'),
              controller: _total,
              enabled: !_locked,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: '30000',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              onChanged: (_) => setState(() {}),
              validator: DebtValidators.total,
            ),
          ),
        LabeledField(
          label: 'Number of monthly EMIs',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in _quickMonths)
                    ChoiceChip(
                      label: Text('$m mo'),
                      selected: _monthsValue == m,
                      onSelected: _locked
                          ? null
                          : (_) => setState(() => _months.text = '$m'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const ValueKey('debt-months'),
                controller: _months,
                enabled: !_locked,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Or type, e.g. 18',
                  prefixIcon: Icon(Icons.repeat_rounded),
                  suffixText: 'months',
                ),
                onChanged: (_) => setState(() {}),
                validator: DebtValidators.months,
              ),
            ],
          ),
        ),
        DatePickField(
          key: const ValueKey('debt-first-due'),
          label: 'First EMI date',
          value: _firstDue,
          enabled: !_locked,
          firstDate: DateTime(now.year - 30),
          lastDate: DateTime(now.year + 40),
          onChanged: (d) => setState(() {
            _firstDue = d;
            _paidBeforeChoice = null;
          }),
          validator: (_) =>
              _firstDue == null ? 'Pick the first EMI date' : null,
        ),
        if (!editing && _pastDue > 0) _paidBeforeField(context),
        _preview(context),
        LabeledField(
          label: 'Category',
          child: DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final c in categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
        ),
        LabeledField(
          label: 'Notes (optional)',
          child: TextFormField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Loan account number, interest rate…',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
