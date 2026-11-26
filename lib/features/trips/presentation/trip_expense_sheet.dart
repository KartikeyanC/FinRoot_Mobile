import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../split/domain/split_dues.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';
import 'trip_detail_screen.dart';

Future<void> openTripExpenseSheet(
  BuildContext context,
  Trip trip,
  Map<String, String> accountNames,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TripExpenseSheet(trip: trip, accountNames: accountNames),
  );
}

/// Log a spend into the trip's jsonb sandbox (web TripWorkspace's form).
class TripExpenseSheet extends ConsumerStatefulWidget {
  const TripExpenseSheet({
    super.key,
    required this.trip,
    required this.accountNames,
  });

  final Trip trip;
  final Map<String, String> accountNames;

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

  List<String> get _accounts {
    final ids = widget.trip.allocation.keys.toList();
    return ids.isEmpty ? const [kTripCashAccountId] : ids;
  }

  @override
  void initState() {
    super.initState();
    _accountId = _accounts.first;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.parse(_amount.text.trim().replaceAll(',', ''));
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final expense = newTripExpense(
      trip: widget.trip,
      amount: amount,
      accountId: _accountId,
      category: _category,
      splitWith: List.of(_splitWith),
      paidBy: _paidBy,
      note: _note.text,
    );
    try {
      await ref
          .read(tripsControllerProvider)
          .addExpense(widget.trip.id, expense);
      navigator.pop();
      final rem = TripTotals.of(widget.trip).remainingByAccount[_accountId];
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            rem != null && rem - amount < 0
                ? '${MoneyFormat.money(amount)} logged — '
                      '${tripAccountName(_accountId, widget.accountNames)} '
                      'pool is now negative'
                : '${MoneyFormat.money(amount)} logged',
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trip = widget.trip;
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
                'Add trip expense',
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                key: const Key('trip-expense-amount'),
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
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
              const SizedBox(height: AppSpacing.md),
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
                onChanged: (v) => setState(() => _accountId = v ?? _accountId),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
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
                label: _busy ? 'Saving…' : 'Log expense',
                icon: Icons.check_rounded,
                expand: true,
                onPressed: _busy ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
