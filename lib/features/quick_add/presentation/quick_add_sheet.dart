import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../transactions/domain/transaction.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/quick_add_controller.dart';
import '../data/custom_categories.dart';
import '../data/custom_subcategories.dart';
import '../domain/expense_subcategories.dart';
import '../domain/quick_add_draft.dart';
import 'widgets/amount_input_field.dart';

/// Quick Add (brief §7) — amount-first Expense / Income / Transfer capture, and
/// (M8) the edit form for an existing transaction.
///
/// Save writes locally only (cache + outbox in one transaction, M5). The sheet
/// closes immediately; a new row shows on Home / the ledger with its "Pending"
/// marker and syncs when it can.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialKind = QuickAddKind.expense,
    this.editing,
    this.prefill,
  });

  final QuickAddKind initialKind;

  /// Starting values for a new entry (a detected payment). Ignored when
  /// [editing].
  final QuickAddPrefill? prefill;

  /// When set, the sheet edits this transaction instead of creating one. The
  /// kind is then fixed (expense/income/transfer have different shapes).
  final TransactionEntity? editing;

  bool get isEditing => editing != null;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  late QuickAddKind _kind;
  String? _category;

  /// Optional subcategory chip (expense); saved as `Sub · note` in the
  /// description, like the web.
  String? _sub;
  final _subKey = GlobalKey();
  String? _paymentMode;
  String? _accountId;
  String? _fromAccountId;
  String? _toAccountId;
  late DateTime _occurredAt;

  bool _busy = false;
  Failure? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _kind = QuickAddKind.values.byName(e.type.name);
      _amount.text = e.amount.amount.toString();
      final split = _kind == QuickAddKind.expense
          ? splitDescription(e.description, subOptionsFor(e.category, const {}))
          : (sub: null, note: e.description ?? '');
      _sub = split.sub;
      _note.text = split.note;
      _occurredAt = e.occurredAt.toLocal();
      _paymentMode = e.paymentMode;
      _category = _kind == QuickAddKind.transfer ? null : e.category;
      if (_kind == QuickAddKind.transfer) {
        _fromAccountId = e.accountId;
        _toAccountId = e.transferToAccountId;
      } else {
        _accountId = e.accountId;
      }
    } else {
      _kind = widget.initialKind;
      _occurredAt = DateTime.now();
      final p = widget.prefill;
      if (p != null) {
        _amount.text = p.amount?.amount.toString() ?? '';
        _note.text = p.note ?? '';
        _paymentMode = p.paymentMode;
        _occurredAt = p.occurredAt ?? _occurredAt;
      }
    }
  }

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
      _category = null;
      _sub = null;
      _error = null;
    });
  }

  /// Custom subs finished loading while editing: a leading `Sub · ` that names
  /// one of the person's own subs becomes the chip (only if the note is still
  /// the stored text, so nothing the person typed is touched).
  void _rehydrateSub(Map<String, List<String>> store) {
    final e = widget.editing;
    if (e == null || _kind != QuickAddKind.expense || _sub != null) return;
    if (_note.text != (e.description ?? '').trim()) return;
    final split = splitDescription(e.description, subOptionsFor(e.category, store));
    if (split.sub == null) return;
    setState(() {
      _sub = split.sub;
      _note.text = split.note;
    });
  }

  Future<void> _addSub(String group) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _AddSubDialog(group: group),
    );
    if (name != null && mounted) setState(() => _sub = name);
  }

  Future<void> _removeSub(String category, String sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove subcategory?'),
        content: Text(
          '"$sub" is removed from your list for everyone in this workspace. '
          'Past transactions keep it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(customSubcategoriesProvider.notifier).remove({
        category,
        ?groupNameForCategory(category),
      }, sub);
      if (mounted && _sub == sub) setState(() => _sub = null);
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  Future<void> _submit() async {
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
            note: _kind == QuickAddKind.expense
                ? composeDescription(_sub, _note.text)
                : _note.text,
            paymentMode: _paymentMode,
            accountId: _accountId,
            fromAccountId: _fromAccountId,
            toAccountId: _toAccountId,
            editingId: widget.editing?.id,
          );
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing ? 'Changes saved' : '${_kind.label} saved',
          ),
        ),
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
    final palette = context.palette;
    ref.listen(customSubcategoriesProvider, (_, next) {
      final store = next.value;
      if (store != null) _rehydrateSub(store);
    });
    final subStore = _kind == QuickAddKind.expense
        ? ref.watch(customSubcategoriesProvider).value ?? const <String, List<String>>{}
        : const <String, List<String>>{};

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isEditing
                ? 'Edit ${_kind.label.toLowerCase()}'
                : 'Add ${_kind.label.toLowerCase()}',
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!canWrite)
            _ViewOnlyNote()
          else ...[
            if (!widget.isEditing) ...[
              _KindSwitch(
                kind: _kind,
                onChanged: _busy ? null : _selectKind,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
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
                          onOccurredAt: (v) => setState(() => _occurredAt = v),
                        )
                      : _EntryForm(
                          kind: _kind,
                          amount: _amount,
                          note: _note,
                          category: _category,
                          customCategories: _kind == QuickAddKind.expense
                              ? ref.watch(customExpenseCategoriesProvider).value ?? const []
                              : const [],
                          paymentMode: _paymentMode,
                          accountId: _accountId,
                          accounts: accounts,
                          occurredAt: _occurredAt,
                          subStore: subStore,
                          sub: _sub,
                          onSub: (v) => setState(() => _sub = v),
                          onAddSub: _addSub,
                          onRemoveSub: _removeSub,
                          onCategory: (v) => setState(() {
                            if (v != _category) _sub = null;
                            _category = v;
                          }),
                          subKey: _subKey,
                          onPaymentMode: (v) =>
                              setState(() => _paymentMode = v),
                          onAccount: (v) => setState(() => _accountId = v),
                          onOccurredAt: (v) => setState(() => _occurredAt = v),
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
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.isEditing
                          ? 'Save changes'
                          : 'Save ${_kind.label.toLowerCase()}',
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Values to open a new Quick Add entry with.
class QuickAddPrefill {
  const QuickAddPrefill({
    this.amount,
    this.note,
    this.paymentMode,
    this.occurredAt,
  });

  final Money? amount;
  final String? note;

  /// One of kPaymentModes.
  final String? paymentMode;
  final DateTime? occurredAt;
}

// ---------------------------------------------------------------------------

class _EntryForm extends StatelessWidget {
  const _EntryForm({
    required this.kind,
    required this.amount,
    required this.note,
    required this.category,
    required this.customCategories,
    required this.paymentMode,
    required this.accountId,
    required this.accounts,
    required this.occurredAt,
    required this.subStore,
    required this.subKey,
    required this.sub,
    required this.onSub,
    required this.onAddSub,
    required this.onRemoveSub,
    required this.onCategory,
    required this.onPaymentMode,
    required this.onAccount,
    required this.onOccurredAt,
  });

  final QuickAddKind kind;
  final TextEditingController amount;
  final TextEditingController note;
  final String? category;

  /// The workspace's own categories (set on the web or from Quick Log).
  final List<String> customCategories;
  final String? paymentMode;
  final String? accountId;
  final List<AccountEntity> accounts;
  final DateTime occurredAt;
  final Map<String, List<String>> subStore;
  final GlobalKey subKey;
  final String? sub;
  final ValueChanged<String?> onSub;
  final ValueChanged<String> onAddSub;
  final void Function(String category, String sub) onRemoveSub;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onPaymentMode;
  final ValueChanged<String?> onAccount;
  final ValueChanged<DateTime> onOccurredAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmountInputField(
          controller: amount,
          validator: QuickAddValidators.amount,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _Label('Category'),
        FormField<String>(
          initialValue: category,
          validator: (v) => QuickAddValidators.category(
            category,
            required: true,
          ),
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PillWrap(
                options: [
                  for (final c in {
                    ...kind.categories,
                    ...customCategories,
                    // An edited row keeps a category this list doesn't know
                    // (e.g. one since removed on the web) instead of breaking
                    // the picker.
                    ?category,
                  })
                    c,
                ],
                selected: category,
                onSelected: (v) {
                  // Close the keyboard so the subcategory chips that appear
                  // below are in view.
                  FocusScope.of(context).unfocus();
                  onCategory(v);
                  field.didChange(v);
                  // Bring the subcategory chips (new below the category) into
                  // view, even at large text sizes.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final c = subKey.currentContext;
                    if (c != null && c.mounted) {
                      Scrollable.ensureVisible(
                        c,
                        alignment: 0.15,
                        duration: const Duration(milliseconds: 200),
                      );
                    }
                  });
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    field.errorText!,
                    style: AppTypography.label.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (kind == QuickAddKind.expense &&
            category != null &&
            groupNameForCategory(category!) != null)
          _SubcategorySection(
            key: subKey,
            category: category!,
            store: subStore,
            selected: sub,
            onSelected: (v) => onSub(v == sub ? null : v),
            onAdd: () => onAddSub(groupNameForCategory(category!)!),
            onRemove: (s) => onRemoveSub(category!, s),
          ),
        const SizedBox(height: AppSpacing.lg),
        const _Label('Payment mode (optional)'),
        _PillWrap(
          options: kPaymentModes,
          selected: paymentMode,
          // Tapping the chosen mode again clears it ("Not set").
          onSelected: (v) => onPaymentMode(v == paymentMode ? null : v),
        ),
        if (accounts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Label('Account (optional)'),
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == accountId)
                ? accountId
                : null,
            isExpanded: true,
            style: _valueStyle(context),
            decoration: _fieldDecoration(Icons.account_balance_outlined),
            items: [
              const DropdownMenuItem<String>(child: Text('Not set')),
              for (final a in accounts)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.name} · ${a.typeLabel}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: onAccount,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        DateTimeField(
          value: occurredAt,
          onChanged: onOccurredAt,
          lastDate: DateTime.now(),
        ),
        const SizedBox(height: AppSpacing.lg),
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
    required this.onOccurredAt,
  });

  final TextEditingController amount;
  final TextEditingController note;
  final List<AccountEntity> accounts;
  final String? fromId;
  final String? toId;
  final DateTime occurredAt;
  final ValueChanged<String?> onFrom;
  final ValueChanged<String?> onTo;
  final ValueChanged<DateTime> onOccurredAt;

  @override
  Widget build(BuildContext context) {
    if (accounts.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          'A transfer moves money between two of your accounts. This '
          'workspace has ${accounts.length == 1 ? 'only one account' : 'no accounts'} '
          'synced yet — add one with the Accounts screen first.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    DropdownMenuItem<String> item(AccountEntity a) => DropdownMenuItem(
      value: a.id,
      child: Text(
        '${a.name} · ${a.typeLabel}',
        overflow: TextOverflow.ellipsis,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AmountInputField(
          controller: amount,
          validator: QuickAddValidators.amount,
        ),
        const SizedBox(height: AppSpacing.xxl),
        const _Label('From'),
        DropdownButtonFormField<String>(
          initialValue: accounts.any((a) => a.id == fromId) ? fromId : null,
          isExpanded: true,
          style: _valueStyle(context),
          decoration: _fieldDecoration(
            Icons.logout_rounded,
            hint: 'Choose an account',
          ),
          items: accounts.map(item).toList(),
          onChanged: onFrom,
          validator: (_) => fromId == null ? 'Choose an account' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Label('To'),
        DropdownButtonFormField<String>(
          initialValue: accounts.any((a) => a.id == toId) ? toId : null,
          isExpanded: true,
          style: _valueStyle(context),
          decoration: _fieldDecoration(
            Icons.login_rounded,
            hint: 'Choose an account',
          ),
          items: accounts.map(item).toList(),
          onChanged: onTo,
          validator: (_) =>
              QuickAddValidators.transferAccounts(fromId: fromId, toId: toId),
        ),
        const SizedBox(height: AppSpacing.lg),
        DateTimeField(
          value: occurredAt,
          onChanged: onOccurredAt,
          lastDate: DateTime.now(),
        ),
        const SizedBox(height: AppSpacing.lg),
        _NoteField(controller: note),
      ],
    );
  }
}

/// Fields carry no floating label: the 12px semibold [_Label] sits above them
/// so the labels line up down the form.
InputDecoration _fieldDecoration(IconData icon, {String? hint}) =>
    InputDecoration(hintText: hint, prefixIcon: Icon(icon));

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

/// The Expense / Income / Transfer switch: one round track, the chosen
/// segment carries the brand gradient.
class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind, required this.onChanged});
  final QuickAddKind kind;
  final ValueChanged<QuickAddKind>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const items = [
      (QuickAddKind.expense, 'Expense', Icons.south_west_rounded),
      (QuickAddKind.income, 'Income', Icons.north_east_rounded),
      (QuickAddKind.transfer, 'Transfer', Icons.swap_horiz_rounded),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: palette.subtle,
        shape: StadiumBorder(side: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          for (final (value, label, icon) in items)
            Expanded(
              child: Semantics(
                button: true,
                selected: kind == value,
                child: Material(
                  color: Colors.transparent,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: kind == value
                        ? ShapeDecoration(
                            shape: const StadiumBorder(),
                            gradient: palette.gradient,
                          )
                        : null,
                    child: InkWell(
                      onTap: onChanged == null ? null : () => onChanged!(value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: kind == value
                                  ? Colors.white
                                  : palette.muted,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _SegmentLabel(
                                label,
                                color: kind == value
                                    ? Colors.white
                                    : palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A wrapping grid of round pills; the chosen one carries the gradient.
class _PillWrap extends StatelessWidget {
  const _PillWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.onLongPress,
    this.trailing,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Optional long-press on a chip (removing a custom subcategory).
  final ValueChanged<String>? onLongPress;

  /// An extra chip after the options (the "Add" chip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final o in options)
          Semantics(
            button: true,
            selected: o == selected,
            label: o,
            excludeSemantics: true,
            child: Material(
              color: o == selected ? Colors.transparent : palette.card,
              shape: StadiumBorder(
                side: BorderSide(
                  color: o == selected ? Colors.transparent : palette.line,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: o == selected
                    ? ShapeDecoration(
                        shape: const StadiumBorder(),
                        gradient: palette.gradient,
                      )
                    : null,
                child: InkWell(
                  onTap: () => onSelected(o),
                  onLongPress: onLongPress == null ? null : () => onLongPress!(o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 9,
                    ),
                    child: Text(
                      o,
                      style: AppTypography.bodyStrong.copyWith(
                        color: o == selected ? Colors.white : palette.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ?trailing,
      ],
    );
  }
}

/// "Subcategory" chips under the category: the person's own subs first, then
/// the built-ins, then a "+ Add" chip. Optional - tap the chosen chip to clear.
class _SubcategorySection extends StatelessWidget {
  const _SubcategorySection({
    super.key,
    required this.category,
    required this.store,
    required this.selected,
    required this.onSelected,
    required this.onAdd,
    required this.onRemove,
  });

  final String category;
  final Map<String, List<String>> store;
  final String? selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final customLower = {
      for (final c in customSubsFor(category, store)) c.toLowerCase(),
    };
    final options = subOptionsFor(category, store);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Subcategory (optional)'),
          _PillWrap(
            options: [
              // An edited row keeps a sub this list no longer has.
              if (selected != null && !options.contains(selected)) selected!,
              ...options,
            ],
            selected: selected,
            onSelected: onSelected,
            onLongPress: (s) {
              if (customLower.contains(s.toLowerCase())) onRemove(s);
            },
            trailing: Semantics(
              button: true,
              label: 'Add subcategory',
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: palette.line)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onAdd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: palette.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: AppTypography.bodyStrong.copyWith(
                            color: palette.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny dialog to create a subcategory under [group]; pops the saved name.
class _AddSubDialog extends ConsumerStatefulWidget {
  const _AddSubDialog({required this.group});
  final String group;

  @override
  ConsumerState<_AddSubDialog> createState() => _AddSubDialogState();
}

class _AddSubDialogState extends ConsumerState<_AddSubDialog> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(customSubcategoriesProvider.notifier)
          .add(widget.group, _name.text);
      if (mounted) Navigator.pop(context, saved);
    } on Failure catch (f) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = f.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New subcategory'),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _busy ? null : _save(),
        decoration: InputDecoration(
          hintText: 'For example Swiggy',
          helperText: 'Under ${widget.group}. Shared with your workspace.',
          helperMaxLines: 2,
          errorText: _error,
          errorMaxLines: 3,
          counterText: '',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// One value style for every field — dropdowns default to the heavier
/// titleMedium, the date and note to bodyLarge, which also left the date box
/// shorter than the rest.
TextStyle? _valueStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge;

/// A segment label that stays on one line, scaling down rather than wrapping
/// ("Transfe / r") on a narrow phone or with large system text.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      softWrap: false,
      style: AppTypography.bodyStrong.copyWith(color: color),
    ),
  );
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Note (optional)'),
        TextFormField(
          controller: controller,
          maxLength: 400,
          textCapitalization: TextCapitalization.sentences,
          decoration: _fieldDecoration(
            Icons.notes_rounded,
            hint: 'Add a note',
          ).copyWith(counterText: ''),
          validator: QuickAddValidators.note,
        ),
      ],
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
