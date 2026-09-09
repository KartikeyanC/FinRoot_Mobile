import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/account_editor_controller.dart';
import '../domain/account.dart';
import '../domain/account_draft.dart';

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
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEditing ? 'Edit account' : 'Add account', style: t.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Account name',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              validator: AccountValidators.name,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Type',
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
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _opening,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Opening balance (optional)',
                prefixIcon: Icon(Icons.currency_rupee),
                helperText: 'As of today. Change the date on the web app.',
              ),
              validator: AccountValidators.openingBalance,
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
                  style: t.bodyMedium?.copyWith(
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
                  : Text(_isEditing ? 'Save changes' : 'Add account'),
            ),
          ],
        ),
      ),
    );
  }
}
