import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../application/net_worth_editor_controller.dart';
import '../domain/net_worth.dart';

Future<void> openNetWorthEntryForm(
  BuildContext context, {
  NetWorthEntry? editing,
  String kind = 'asset',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EntryFormSheet(editing: editing, initialKind: kind),
  );
}

class _EntryFormSheet extends ConsumerStatefulWidget {
  const _EntryFormSheet({this.editing, required this.initialKind});
  final NetWorthEntry? editing;
  final String initialKind;

  @override
  ConsumerState<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends ConsumerState<_EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late String _kind;
  late String _group;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  List<({String id, String label})> get _groups =>
      _kind == 'asset' ? kAssetGroups : kLiabilityGroups;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _kind = e?.kind ?? widget.initialKind;
    _group = e?.group ?? _groups.first.id;
    if (e != null) {
      _name.text = e.name;
      _amount.text = e.amount.amount.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _setKind(String kind) {
    setState(() {
      _kind = kind;
      _group = _groups.first.id;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final draft = NetWorthDraft(
      kind: _kind,
      group: _group,
      name: _name.text,
      amount: Money.tryParse(_amount.text)!,
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(netWorthEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!.id, draft);
      } else {
        await c.add(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Item updated' : 'Item added')),
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit item' : 'Add to net worth',
              style: tt.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_isEditing)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'asset', label: Text('Asset')),
                  ButtonSegment(value: 'liability', label: Text('Liability')),
                ],
                selected: {_kind},
                onSelectionChanged: _busy ? null : (s) => _setKind(s.first),
              ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Group',
                prefixIcon: Icon(Icons.folder_open_outlined),
              ),
              items: [
                for (final g in _groups)
                  DropdownMenuItem(value: g.id, child: Text(g.label)),
              ],
              onChanged: (v) => setState(() => _group = v ?? _group),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: NetWorthValidators.name,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: NetWorthValidators.amount,
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
                  style: tt.bodyMedium?.copyWith(
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
                  : Text(_isEditing ? 'Save changes' : 'Add item'),
            ),
          ],
        ),
      ),
    );
  }
}
