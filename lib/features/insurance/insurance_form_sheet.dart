import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/failure.dart';
import '../../design/design.dart';
import '../accounts/presentation/wealth_kit.dart';
import 'insurance.dart';

Future<void> openPolicyForm(BuildContext context, {InsurancePolicy? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PolicyFormSheet(editing: editing),
    );

/// Picks a PDF or photo for a policy. Overridden in tests.
final policyDocPickerProvider = Provider<Future<PolicyDoc?> Function()>(
  (ref) => () async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      dialogTitle: 'Choose the policy document',
    );
    if (f == null) return null;
    return (name: f.name, bytes: await f.xFile.readAsBytes());
  },
  name: 'policyDocPicker',
);

/// Opens a policy's document in the browser or a viewer app. Overridden in
/// tests.
final openPolicyDocProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
  name: 'openPolicyDoc',
);

class _PolicyFormSheet extends ConsumerStatefulWidget {
  const _PolicyFormSheet({this.editing});
  final InsurancePolicy? editing;

  @override
  ConsumerState<_PolicyFormSheet> createState() => _PolicyFormSheetState();
}

class _PolicyFormSheetState extends ConsumerState<_PolicyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _provider = TextEditingController();
  final _number = TextEditingController();
  final _cover = TextEditingController();
  final _premium = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'health';
  String _frequency = 'Annual';
  String _structure = 'Regular-Pay';
  DateTime? _due;
  PolicyDoc? _newDoc;
  bool _removeDoc = false;
  bool _busy = false;
  String? _error;

  InsurancePolicy? get _editing => widget.editing;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _name.text = e.name;
      _provider.text = e.provider ?? '';
      _number.text = e.policyNumber ?? '';
      _cover.text = e.sumInsured > 0 ? _plain(e.sumInsured) : '';
      _premium.text = e.premium > 0 ? _plain(e.premium) : '';
      _notes.text = e.notes ?? '';
      if (kInsuranceCategories.containsKey(e.category)) _category = e.category;
      if (kPaymentFrequencies.containsKey(e.frequency)) {
        _frequency = e.frequency!;
      }
      if (kPayStructures.contains(e.payStructure)) _structure = e.payStructure!;
      _due = e.due;
    } else {
      final now = DateTime.now();
      _due = DateTime(now.year + 1, now.month, now.day);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _provider, _number, _cover, _premium, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  PolicyDraft _draft() => PolicyDraft(
    name: _name.text,
    category: _category,
    provider: _provider.text,
    policyNumber: _number.text,
    sumInsured: _num(_cover),
    premium: _num(_premium),
    frequency: _frequency,
    payStructure: _structure,
    due: _due,
    notes: _notes.text,
  );

  Future<void> _run(
    Future<void> Function(InsuranceEditor e) action,
    String done,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(insuranceEditorProvider));
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
    await _run(
      (ed) => e == null
          ? ed.add(_draft(), doc: _newDoc)
          : ed.edit(e, _draft(), doc: _newDoc, removeDoc: _removeDoc),
      e == null ? 'Policy added' : 'Policy updated',
    );
  }

  Future<void> _delete() async {
    final e = _editing!;
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${e.name}?',
      message:
          'The policy${e.documentPath != null ? ' and its document are' : ' is'} '
          'removed here and on the web. This can\'t be undone.',
    );
    if (!ok || !mounted) return;
    await _run((ed) => ed.delete(e), 'Policy deleted');
  }

  Future<void> _pickDoc() async {
    final doc = await ref.read(policyDocPickerProvider)();
    if (doc == null || !mounted) return;
    final why = docRejectionReason(doc.name, doc.bytes.length);
    setState(() {
      if (why != null) {
        _error = why;
      } else {
        _error = null;
        _newDoc = doc;
        _removeDoc = false;
      }
    });
  }

  Future<void> _viewDoc() async {
    final path = _editing?.documentPath;
    if (path == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final url = await ref.read(insuranceGatewayProvider).signedUrl(path);
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t open the document. Try again.'),
        ),
      );
      return;
    }
    await ref.read(openPolicyDocProvider)(Uri.parse(url));
  }

  String? _required(String? v, String what) =>
      (v?.trim() ?? '').isEmpty ? 'Add the $what' : null;

  String? _money(String? v, {required bool required}) {
    final t = (v ?? '').replaceAll(',', '').trim();
    if (t.isEmpty) return required ? 'Enter an amount' : null;
    final n = double.tryParse(t);
    if (n == null || !n.isFinite || n < 0) return 'Enter an amount';
    if (n > 999999999999) return 'That amount is too large';
    return null;
  }

  Widget _documentSection(BuildContext context) {
    final palette = context.palette;
    final e = _editing;
    final hasStored = e?.documentPath != null && !_removeDoc;
    final compact = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );
    final String status;
    if (_newDoc != null) {
      status = '${_newDoc!.name} will be attached';
    } else if (hasStored) {
      status = e!.documentName ?? 'Document attached';
    } else if (e?.hasLegacyDocument ?? false) {
      status = 'An older document is attached; open it on the web';
    } else {
      status = 'No document attached';
    }
    return LabeledField(
      label: 'Policy document (optional)',
      child: Container(
        key: const ValueKey('policy-doc'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  _newDoc != null || hasStored
                      ? Icons.description_rounded
                      : Icons.description_outlined,
                  color: palette.muted,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(color: palette.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasStored && _newDoc == null)
                  OutlinedButton.icon(
                    style: compact,
                    onPressed: _viewDoc,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View'),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('policy-doc-pick'),
                  style: compact,
                  onPressed: _busy ? null : _pickDoc,
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: Text(
                    _newDoc != null || hasStored
                        ? 'Replace'
                        : 'Attach PDF or photo',
                  ),
                ),
                if (_newDoc != null || hasStored)
                  TextButton(
                    style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => setState(() {
                      if (_newDoc != null) {
                        _newDoc = null;
                      } else {
                        _removeDoc = true;
                      }
                    }),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing != null;
    final now = DateTime.now();
    return SheetFrame(
      formKey: _formKey,
      title: editing ? 'Edit policy' : 'Add a policy',
      subtitle:
          'Health, life, vehicle or gadget cover: what it covers, the '
          'premium and when it\'s due.',
      primaryLabel: editing ? 'Save changes' : 'Add policy',
      onPrimary: _submit,
      busy: _busy,
      error: _error,
      pinActions: true,
      extraActions: [
        if (editing)
          TextButton.icon(
            key: const ValueKey('policy-delete'),
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete policy'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
      children: [
        LabeledField(
          label: 'Policy name',
          child: TextFormField(
            key: const ValueKey('policy-name'),
            controller: _name,
            autofocus: !editing,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Family health cover',
              prefixIcon: Icon(Icons.verified_user_outlined),
            ),
            validator: (v) => _required(v, 'policy name'),
          ),
        ),
        LabeledField(
          label: 'Type',
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final e in kInsuranceCategories.entries)
                ChoiceChip(
                  label: Text('${e.value.$2} ${e.value.$1}'),
                  selected: _category == e.key,
                  onSelected: (_) => setState(() => _category = e.key),
                ),
            ],
          ),
        ),
        LabeledField(
          label: 'Insurer',
          child: TextFormField(
            key: const ValueKey('policy-provider'),
            controller: _provider,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Star Health, LIC, HDFC Ergo…',
              prefixIcon: Icon(Icons.apartment_outlined),
            ),
            validator: (v) => _required(v, 'insurer'),
          ),
        ),
        LabeledField(
          label: 'Policy number',
          child: TextFormField(
            key: const ValueKey('policy-number'),
            controller: _number,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.tag_rounded),
            ),
            validator: (v) => _required(v, 'policy number'),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Cover (sum insured)',
                child: TextFormField(
                  key: const ValueKey('policy-cover'),
                  controller: _cover,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '500000',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  validator: (v) => _money(v, required: false),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: 'Premium',
                child: TextFormField(
                  key: const ValueKey('policy-premium'),
                  controller: _premium,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '18000',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  validator: (v) => _money(v, required: true),
                ),
              ),
            ),
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: LabeledField(
                label: 'Premium paid',
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('policy-frequency'),
                  initialValue: _frequency,
                  isExpanded: true,
                  items: [
                    for (final f in kPaymentFrequencies.keys)
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: (v) =>
                      setState(() => _frequency = v ?? _frequency),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: LabeledField(
                label: 'Pay structure',
                child: DropdownButtonFormField<String>(
                  initialValue: _structure,
                  isExpanded: true,
                  items: [
                    for (final s in kPayStructures)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) =>
                      setState(() => _structure = v ?? _structure),
                ),
              ),
            ),
          ],
        ),
        DatePickField(
          key: const ValueKey('policy-due'),
          label: 'Next premium due',
          value: _due,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 30),
          onChanged: (d) => setState(() => _due = d),
        ),
        _documentSection(context),
        LabeledField(
          label: 'Notes (optional)',
          child: TextFormField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Nominee, agent, what it covers…',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
