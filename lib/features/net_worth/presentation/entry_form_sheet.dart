import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
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
    return SheetFrame(
      formKey: _formKey,
      title: _isEditing ? 'Edit item' : 'Add to net worth',
      primaryLabel: _isEditing ? 'Save changes' : 'Add item',
      onPrimary: _submit,
      busy: _busy,
      error: _error?.message,
      children: [
        if (!_isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'asset', label: Text('Asset')),
                ButtonSegment(value: 'liability', label: Text('Liability')),
              ],
              selected: {_kind},
              onSelectionChanged: _busy ? null : (s) => _setKind(s.first),
            ),
          ),
        LabeledField(
          label: 'Group',
          child: DropdownButtonFormField<String>(
            initialValue: _group,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.folder_open_outlined),
            ),
            items: [
              for (final g in _groups)
                DropdownMenuItem(value: g.id, child: Text(g.label)),
            ],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
        ),
        LabeledField(
          label: 'Name',
          child: TextFormField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'HDFC savings, Car loan…',
              prefixIcon: Icon(Icons.label_outline),
            ),
            validator: NetWorthValidators.name,
          ),
        ),
        LabeledField(
          label: 'Amount',
          child: TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.currency_rupee),
            ),
            validator: NetWorthValidators.amount,
          ),
        ),
      ],
    );
  }
}
