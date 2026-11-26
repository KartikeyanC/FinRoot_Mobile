import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/currency.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../split/domain/split_dues.dart';
import '../../split/presentation/split_state_views.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';
import 'trip_detail_screen.dart';

/// Log a new trip expense, or — with [editing] — change or delete one.
Future<void> openTripExpenseSheet(
  BuildContext context,
  Trip trip,
  Map<String, String> accountNames, {
  TripExpense? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TripExpenseSheet(
      trip: trip,
      accountNames: accountNames,
      editing: editing,
    ),
  );
}

/// A spend in the trip's jsonb sandbox (web TripWorkspace's form).
class TripExpenseSheet extends ConsumerStatefulWidget {
  const TripExpenseSheet({
    super.key,
    required this.trip,
    required this.accountNames,
    this.editing,
  });

  final Trip trip;
  final Map<String, String> accountNames;

  /// The expense being edited; null = logging a new one.
  final TripExpense? editing;

  @override
  ConsumerState<TripExpenseSheet> createState() => _TripExpenseSheetState();
}

class _TripExpenseSheetState extends ConsumerState<TripExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _accountId;
  String _category = kTripCategories.first;
  final _splitWith = <String>[];
  String _paidBy = kTripPayerYou;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  List<String> get _accounts {
    final ids = widget.trip.allocation.keys.toList();
    return ids.isEmpty ? const [kTripCashAccountId] : ids;
  }

  bool get _payerIsFriend => widget.trip.isShared && _paidBy != kTripPayerYou;

  @override
  void initState() {
    super.initState();
    _accountId = _accounts.first;
    final e = widget.editing;
    if (e != null) {
      _amount.text = e.amount == e.amount.roundToDouble()
          ? e.amount.toStringAsFixed(0)
          : e.amount.toString();
      _note.text = e.note ?? '';
      _category = kTripCategories.contains(e.category) ? e.category : 'Other';
      if (_accounts.contains(e.accountId)) _accountId = e.accountId;
      final trip = widget.trip;
      if (trip.isShared && !e.paidByYou && trip.companions.contains(e.paidBy)) {
        _paidBy = e.paidBy!;
      }
      _splitWith.addAll([
        for (final n in e.splitWith ?? const <String>[])
          if (trip.companions.contains(n) && n != e.paidBy) n,
      ]);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _money(double n) =>
      MoneyFormat.money(n, currency: widget.trip.currency);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amount.text.trim().replaceAll(',', ''));
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final trip = widget.trip;
    final original = widget.editing;
    final expense = original == null
        ? newTripExpense(
            trip: trip,
            amount: amount,
            accountId: _accountId,
            category: _category,
            splitWith: List.of(_splitWith),
            paidBy: _paidBy,
            note: _note.text,
          )
        : editedTripExpense(
            trip: trip,
            original: original,
            amount: amount,
            accountId: _accountId,
            category: _category,
            splitWith: List.of(_splitWith),
            paidBy: _paidBy,
            note: _note.text,
          );
    try {
      final c = ref.read(tripsControllerProvider);
      if (original == null) {
        await c.addExpense(trip.id, expense);
      } else {
        await c.updateExpense(trip.id, expense);
      }
      navigator.pop();
      // The pool after this save; an edited expense's old amount comes back.
      final back =
          original != null &&
              original.paidByYou &&
              original.accountId == _accountId
          ? original.amount
          : 0.0;
      final rem = TripTotals.of(trip).remainingByAccount[_accountId];
      final negative =
          !_payerIsFriend && rem != null && rem + back - amount < 0;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            original != null
                ? 'Expense updated · ${_money(amount)}'
                : negative
                ? '${_money(amount)} logged — '
                      '${tripAccountName(_accountId, widget.accountNames)} '
                      'pool is now negative'
                : _payerIsFriend
                ? '${_money(amount)} logged · paid by $_paidBy'
                : '${_money(amount)} logged',
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
    final e = widget.editing!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text(
          '${_money(e.amount)} · ${e.category} comes off the trip. '
          'Settle-up changes with it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(tripsControllerProvider)
          .removeExpense(widget.trip.id, e.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Expense deleted')));
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trip = widget.trip;
    final symbol = currencySymbol(trip.currency);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenGutter),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isEdit ? 'Edit trip expense' : 'Add trip expense',
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('trip-expense-amount'),
                controller: _amount,
                autofocus: !_isEdit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: symbol.isEmpty ? '${trip.currency} ' : '$symbol ',
                ),
                validator: (v) {
                  final n = double.tryParse(
                    (v ?? '').trim().replaceAll(',', ''),
                  );
                  if (n == null) return 'Enter an amount';
                  if (n <= 0) return 'Amount must be more than zero';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final c in kTripCategories)
                    ChoiceChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              if (trip.isShared) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  key: const Key('trip-expense-paid-by'),
                  initialValue: _paidBy,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: [
                    const DropdownMenuItem(
                      value: kTripPayerYou,
                      child: Text(kMe),
                    ),
                    for (final c in trip.companions)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) =>
                      setState(() => _paidBy = v ?? kTripPayerYou),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_payerIsFriend)
                InlineNote(
                  '$_paidBy paid — nothing is taken from your trip pool.',
                  icon: Icons.info_outline,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(labelText: 'Paid from'),
                  items: [
                    for (final id in _accounts)
                      DropdownMenuItem(
                        value: id,
                        child: Text(tripAccountName(id, widget.accountNames)),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => _accountId = v ?? _accountId),
                ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                key: const Key('trip-expense-note'),
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              if (!trip.isSolo && trip.companions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Split with',
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final c in trip.companions)
                      FilterChip(
                        label: Text(c),
                        selected:
                            _splitWith.contains(c) ||
                            (_paidBy == c && _paidBy != kTripPayerYou),
                        onSelected: _paidBy == c
                            ? null
                            : (on) => setState(
                                () => on
                                    ? _splitWith.add(c)
                                    : _splitWith.remove(c),
                              ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You always share it. A companion who paid shares it too.',
                  style: AppTypography.caption.copyWith(color: palette.muted),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: AppTypography.body.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PillButton(
                label: _busy
                    ? 'Saving…'
                    : _isEdit
                    ? 'Save changes'
                    : 'Log expense',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: _busy ? null : _submit,
              ),
              if (_isEdit) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  key: const Key('trip-expense-delete'),
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete expense'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
