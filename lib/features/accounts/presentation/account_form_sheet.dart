import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../application/account_editor_controller.dart';
import '../domain/account.dart';
import '../domain/account_draft.dart';
import 'wealth_kit.dart';

/// Opens the create / edit account sheet.
Future<void> openAccountForm(BuildContext context, {AccountEntity? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AccountFormSheet(editing: editing),
  );
}

class _AccountFormSheet extends ConsumerStatefulWidget {
  const _AccountFormSheet({this.editing});
  final AccountEntity? editing;

  @override
  ConsumerState<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<_AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _opening = TextEditingController();

  late String _type;
  DateTime? _openingDate;
  bool _dateTouched = false;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _type = e?.type ?? 'bank';
    if (e != null) {
      _name.text = e.name;
      if (e.openingBalance != null) {
        _opening.text = e.openingBalance!.amount.toString();
      }
      _loadOpeningDate(e.id);
    } else {
      final now = DateTime.now();
      _openingDate = DateTime(now.year, now.month, now.day);
    }
  }

  Future<void> _loadOpeningDate(String id) async {
    try {
      final d = await ref.read(accountEditorControllerProvider).openingDate(id);
      if (!mounted || _dateTouched || d == null) return;
      setState(() => _openingDate = d);
    } on Object {
      // Best effort: the picker stays empty and an edit leaves the date alone.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = AccountDraft(
      name: _name.text,
      type: _type,
      openingBalance: Money.tryParse(_opening.text),
      openingDate: _openingDate,
    );

    setState(() => _busy = true);
    try {
      final controller = ref.read(accountEditorControllerProvider);
      if (_isEditing) {
        await controller.update(widget.editing!.id, draft);
      } else {
        await controller.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Account updated' : 'Account added'),
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
    return SheetFrame(
      formKey: _formKey,
      title: _isEditing ? 'Edit account' : 'Add account',
      primaryLabel: _isEditing ? 'Save changes' : 'Add account',
      onPrimary: _submit,
      busy: _busy,
      error: _error?.message,
      children: [
        LabeledField(
          label: 'Account name',
          child: TextFormField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Account name',
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            validator: AccountValidators.name,
          ),
        ),
        LabeledField(
          label: 'Type',
          child: DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final type in kAccountTypes)
                DropdownMenuItem(
                  value: type,
                  child: Text(accountTypeLabel(type)),
                ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
        ),
        LabeledField(
          label: 'Opening balance (optional)',
          child: TextFormField(
            controller: _opening,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: AccountValidators.openingBalance,
          ),
        ),
        DatePickField(
          key: const ValueKey('account-opening-date'),
          label: 'Opening date',
          value: _openingDate,
          firstDate: DateTime(1970),
          lastDate: DateTime.now(),
          helper: 'The day the opening balance is as of.',
          enabled: !_busy,
          onChanged: (d) => setState(() {
            _dateTouched = true;
            _openingDate = d;
          }),
        ),
      ],
    );
  }
}
