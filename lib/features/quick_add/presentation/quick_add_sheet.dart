import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/quick_add_controller.dart';
import '../domain/quick_add_draft.dart';
import 'widgets/amount_input_field.dart';

/// Quick Add (brief §7) — amount-first Expense / Income / Transfer capture.
///
/// Save writes locally only (cache + outbox in one transaction, M5). The sheet
/// closes immediately; the new row appears on Home with a "Pending" marker and
/// syncs when it can. Presented as a bottom sheet on a phone, a dialog on a
/// tablet (see `openQuickAdd`).
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.initialKind = QuickAddKind.expense});

  final QuickAddKind initialKind;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  late QuickAddKind _kind = widget.initialKind;
  String? _category;
  String? _paymentMode;
  String? _fromAccountId;
  String? _toAccountId;
  DateTime _occurredAt = DateTime.now();

  bool _busy = false;
  Failure? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _selectKind(QuickAddKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _category = null; // category lists differ per kind
      _error = null;
    });
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      // keep the current wall-clock time, just move the day
      _occurredAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _occurredAt.hour,
        _occurredAt.minute,
      );
    });
  }

  Future<void> _submit(List<AccountEntity> accounts) async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      await ref
          .read(quickAddControllerProvider)
          .submit(
            kind: _kind,
            amount: Money.tryParse(_amount.text)!,
            occurredAt: _occurredAt,
            category: _category,
            note: _note.text,
            paymentMode: _paymentMode,
            fromAccountId: _fromAccountId,
            toAccountId: _toAccountId,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${_kind.label} saved')),
      );
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final accounts = ref.watch(workspaceAccountsProvider).value ?? const [];
    final t = Theme.of(context).textTheme;

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
          Text('Add', style: t.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          if (!canWrite)
            _ViewOnlyNote()
          else ...[
            SegmentedButton<QuickAddKind>(
              segments: const [
                ButtonSegment(
                  value: QuickAddKind.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.south_west_rounded),
                ),
                ButtonSegment(
                  value: QuickAddKind.income,
                  label: Text('Income'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: QuickAddKind.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: _busy
                  ? null
                  : (s) => _selectKind(s.first),
            ),
            const SizedBox(height: AppSpacing.xl),
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: _kind == QuickAddKind.transfer
                      ? _TransferForm(
                          amount: _amount,
                          note: _note,
                          accounts: accounts,
                          fromId: _fromAccountId,
                          toId: _toAccountId,
                          occurredAt: _occurredAt,
                          onFrom: (v) => setState(() => _fromAccountId = v),
                          onTo: (v) => setState(() => _toAccountId = v),
                          onPickDate: _pickDate,
                        )
                      : _EntryForm(
                          kind: _kind,
                          amount: _amount,
                          note: _note,
                          category: _category,
                          paymentMode: _paymentMode,
                          occurredAt: _occurredAt,
                          onCategory: (v) => setState(() => _category = v),
                          onPaymentMode: (v) =>
                              setState(() => _paymentMode = v),
                          onPickDate: _pickDate,
                        ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorNote(_error!.message),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _busy ? null : () => _submit(accounts),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Save ${_kind.label.toLowerCase()}'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EntryForm extends StatelessWidget {
  const _EntryForm({
    required this.kind,
    required this.amount,
    required this.note,
    required this.category,
    required this.paymentMode,
    required this.occurredAt,
    required this.onCategory,
    required this.onPaymentMode,
    required this.onPickDate,
  });

  final QuickAddKind kind;
  final TextEditingController amount;
  final TextEditingController note;
  final String? category;
  final String? paymentMode;
  final DateTime occurredAt;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onPaymentMode;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmountInputField(
          controller: amount,
          validator: QuickAddValidators.amount,
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Category',
            prefixIcon: Icon(Icons.sell_outlined),
          ),
          items: [
            for (final c in kind.categories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: onCategory,
          validator: (v) =>
              QuickAddValidators.category(v, required: true),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: paymentMode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Payment mode (optional)',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
          items: [
            const DropdownMenuItem<String>(child: Text('Not set')),
            for (final m in kPaymentModes)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: onPaymentMode,
        ),
        const SizedBox(height: AppSpacing.md),
        _DateField(occurredAt: occurredAt, onTap: onPickDate),
        const SizedBox(height: AppSpacing.md),
        _NoteField(controller: note),
      ],
    );
  }
}

class _TransferForm extends StatelessWidget {
  const _TransferForm({
    required this.amount,
    required this.note,
    required this.accounts,
    required this.fromId,
    required this.toId,
    required this.occurredAt,
    required this.onFrom,
    required this.onTo,
    required this.onPickDate,
  });

  final TextEditingController amount;
  final TextEditingController note;
  final List<AccountEntity> accounts;
  final String? fromId;
  final String? toId;
  final DateTime occurredAt;
  final ValueChanged<String?> onFrom;
  final ValueChanged<String?> onTo;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    if (accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'A transfer moves money between two of your accounts. This '
          'workspace has ${accounts.length == 1 ? 'only one account' : 'no accounts'} '
          'synced yet — add accounts on the web app (mobile support arrives '
          'in M8).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    DropdownMenuItem<String> item(AccountEntity a) => DropdownMenuItem(
      value: a.id,
      child: Text('${a.name} · ${a.typeLabel}', overflow: TextOverflow.ellipsis),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmountInputField(
          controller: amount,
          validator: QuickAddValidators.amount,
        ),
        const SizedBox(height: AppSpacing.lg),
        DropdownButtonFormField<String>(
          initialValue: fromId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'From',
            prefixIcon: Icon(Icons.logout_rounded),
          ),
          items: accounts.map(item).toList(),
          onChanged: onFrom,
          validator: (_) => fromId == null ? 'Choose an account' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: toId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'To',
            prefixIcon: Icon(Icons.login_rounded),
          ),
          items: accounts.map(item).toList(),
          onChanged: onTo,
          validator: (_) => QuickAddValidators.transferAccounts(
            fromId: fromId,
            toId: toId,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _DateField(occurredAt: occurredAt, onTap: onPickDate),
        const SizedBox(height: AppSpacing.md),
        _NoteField(controller: note),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.occurredAt, required this.onTap});
  final DateTime occurredAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.field,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.event_outlined),
        ),
        child: Text(RelativeTime.dayLabel(occurredAt)),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: 400,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Note (optional)',
        prefixIcon: Icon(Icons.notes_rounded),
        counterText: '',
      ),
      validator: QuickAddValidators.note,
    );
  }
}

class _ViewOnlyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Your role in this workspace is view-only. Ask a workspace '
              'owner or admin to record transactions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
