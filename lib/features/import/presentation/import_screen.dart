import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money_format.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../payment_capture/domain/bank_sms.dart';
import '../../payment_capture/domain/ingest_hash.dart';
import '../../payment_capture/domain/sms_fields.dart';
import '../../sync/application/sync_engine.dart';
import '../../transactions/presentation/widgets/category_style.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/import_gateway.dart';
import '../data/pdf_text_reader.dart';
import '../domain/import_rows.dart';
import '../domain/pdf_statement.dart';

/// A picked file: its name and bytes. Overridden in tests.
typedef ImportFile = ({String name, List<int> bytes});
typedef ImportFilePicker = Future<ImportFile?> Function();

final importFilePickerProvider = Provider<ImportFilePicker>(
  (ref) => () async {
    // On Android the extension filter turns into a MIME-type filter, and many
    // phones label a .csv as a type it doesn't list ("text/comma-separated-
    // values", "application/octet-stream"), so the file shows greyed out and
    // can't be picked. Show every file there; the screen checks the name.
    final android = Platform.isAndroid;
    final f = await FilePicker.pickFile(
      type: android ? FileType.any : FileType.custom,
      allowedExtensions: android ? null : const ['csv', 'xlsx', 'xls', 'pdf'],
      dialogTitle: 'Choose a CSV, Excel or PDF statement',
    );
    if (f == null) return null;
    return (name: f.name, bytes: await f.xFile.readAsBytes());
  },
  name: 'importFilePicker',
);

/// Reads a PDF's words with positions. Overridden in tests.
final importPdfReaderProvider = Provider<PdfWordReader>(
  (ref) => readPdfWords,
  name: 'importPdfReader',
);

/// Pulls the imported rows into the local ledger. Overridden in tests.
final importRefreshProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(syncEngineProvider.notifier).syncNow(force: true),
  name: 'importRefresh',
);

/// Import: transactions from a CSV / Excel file (the web's template, or a
/// bank statement with Debit / Credit columns) or from pasted bank SMS. Rows
/// are previewed, can be unticked or recategorised, and are saved with the
/// web's duplicate key, so importing the same thing twice adds nothing.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _sms = TextEditingController();
  List<ImportRow> _rows = const [];
  Set<int> _off = {};
  String? _source;
  String? _note;
  bool _busy = false;
  ImportOutcome? _done;
  String? _error;

  @override
  void dispose() {
    _sms.dispose();
    super.dispose();
  }

  List<ImportRow> get _chosen => [
    for (var i = 0; i < _rows.length; i++)
      if (!_off.contains(i)) _rows[i],
  ];

  void _show(List<ImportRow> rows, {required String source, String? note}) {
    setState(() {
      _rows = rows;
      _off = {};
      _source = source;
      _note = note;
      _done = null;
      _error = rows.isEmpty
          ? 'No transactions found. Check the file has a date and an amount '
                'column, or try the template.'
          : null;
    });
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final f = await ref.read(importFilePickerProvider)();
    if (f == null || !mounted) return;
    final lower = f.name.toLowerCase();
    final kind = const [
      '.csv',
      '.xlsx',
      '.xls',
      '.pdf',
    ].where(lower.endsWith).firstOrNull;
    if (kind == null) {
      setState(() => _error = 'Choose a .csv, .xlsx, .xls or .pdf file.');
      return;
    }
    try {
      final List<List<Object?>> table;
      switch (kind) {
        case '.pdf':
          final t = await _pdfTable(f);
          if (t == null || !mounted) return;
          table = t;
        case '.xlsx':
        case '.xls':
          final t = await _sheetTable(f, xls: kind == '.xls');
          if (t == null || !mounted) return;
          table = t;
        default:
          table = csvTable(f.bytes);
      }
      final parsed = parseImportTable(table);
      final d = dedupeInFile(parsed.rows);
      _show(
        d.rows,
        source: f.name,
        note: [
          if (parsed.undated > 0)
            '${parsed.undated} row${parsed.undated == 1 ? '' : 's'} had a '
                'date we couldn\'t read and ${parsed.undated == 1 ? 'was' : 'were'} '
                'left out',
          if (d.duplicates > 0)
            '${d.duplicates} repeated row${d.duplicates == 1 ? '' : 's'} '
                'counted once',
        ].join(' · '),
      );
    } on UnsupportedSpreadsheetProtectionException catch (e) {
      setState(() => _error = e.message(f.name));
    } on Object {
      setState(
        () => _error =
            'Couldn\'t read ${f.name}. Save it as CSV or .xlsx and try again.',
      );
    }
  }

  /// A PDF statement's table, asking for its password when it has one.
  /// Null when the PDF can't be read (the reason is shown).
  Future<List<List<Object?>>?> _pdfTable(ImportFile f) async {
    final read = ref.read(importPdfReaderProvider);
    String? password;
    while (true) {
      try {
        final words = await read(f.bytes, password: password);
        final table = pdfStatementTable(pdfLines(words));
        if (table.isEmpty && mounted) {
          setState(
            () => _error =
                'Couldn\'t find a transactions table in ${f.name}. Download '
                'the statement as Excel or CSV from your bank instead.',
          );
          return null;
        }
        return table;
      } on PdfReadException catch (e) {
        if (!mounted) return null;
        switch (e.problem) {
          case PdfReadProblem.needsPassword:
          case PdfReadProblem.wrongPassword:
            password = await _askPdfPassword(
              f.name,
              wrong: e.problem == PdfReadProblem.wrongPassword,
            );
            if (password == null) {
              if (mounted) {
                setState(
                  () => _error =
                      '${f.name} is password-protected. Choose it again and '
                      'enter its password to import it.',
                );
              }
              return null;
            }
          case PdfReadProblem.noText:
            setState(
              () => _error =
                  '${f.name} is a scanned image, so there is no text to '
                  'read. Download the statement as Excel or CSV from your '
                  'bank instead.',
            );
            return null;
          case PdfReadProblem.unreadable:
            setState(
              () => _error =
                  'Couldn\'t open ${f.name} as a PDF. Download the statement '
                  'as Excel or CSV from your bank instead.',
            );
            return null;
        }
      }
    }
  }

  /// An Excel file's first sheet, asking for its password when it has one.
  /// Null when the user cancels the password (the reason is shown).
  Future<List<List<Object?>>?> _sheetTable(
    ImportFile f, {
    required bool xls,
  }) async {
    String? password;
    while (true) {
      try {
        return xls
            ? xlsTable(f.bytes, password: password)
            : xlsxTable(f.bytes, password: password);
      } on ProtectedSpreadsheetException catch (e) {
        if (!mounted) return null;
        password = await _askPdfPassword(
          f.name,
          wrong: e.wrongPassword,
          spreadsheet: true,
        );
        if (password == null) {
          if (mounted) {
            setState(
              () => _error =
                  '${f.name} is password-protected. Choose it again and '
                  'enter its password to import it.',
            );
          }
          return null;
        }
      }
    }
  }

  Future<String?> _askPdfPassword(
    String name, {
    required bool wrong,
    bool spreadsheet = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) =>
        _PdfPasswordDialog(name: name, wrong: wrong, spreadsheet: spreadsheet),
  );

  void _readSms() {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final chunks = _sms.text
        .split(RegExp(r'\n\s*\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final rows = <ImportRow>[];
    var unread = 0;
    var undated = 0;
    for (final c in chunks) {
      final e = extractBankSms(c, receivedAt: now);
      if (e == null) {
        unread++;
        continue;
      }
      // A pasted message has no arrival time: keep the date printed in it,
      // however old ("12-Nov-26", "Nov 12, 2026", "12th Nov").
      final printed = messageDateIn(c, now: now);
      if (printed == null) undated++;
      final income = e.type == IngestType.income;
      rows.add(
        ImportRow(
          date: printed ?? now,
          type: income ? 'income' : 'expense',
          amount: e.amount,
          category: income ? 'Other' : 'Uncategorized',
          description: [
            ?e.merchant,
            if (e.paymentMode != null) 'via ${e.paymentMode}',
          ].join(' '),
        ),
      );
    }
    final d = dedupeInFile(rows);
    _show(
      d.rows,
      source: 'Pasted messages',
      note: [
        if (unread > 0)
          '$unread message${unread == 1 ? '' : 's'} weren\'t payments '
              '(OTPs, reminders, failed payments) and were left out',
        if (undated > 0)
          '$undated message${undated == 1 ? '' : 's'} had no date, so today '
              'is used. Tap the date to change it',
      ].join(' · '),
    );
  }

  Future<void> _pickDate(int i) async {
    final r = _rows[i];
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: r.date.isAfter(now) ? now : r.date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _rows = [..._rows]..[i] = r.copyWith(date: picked);
    });
  }

  Future<void> _shareTemplate() async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}finroot-import-template.csv',
    );
    await file.writeAsString(kImportTemplateCsv, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'FinRoot import template',
      ),
    );
  }

  Future<void> _pickCategory(int i) async {
    final r = _rows[i];
    final options = r.isIncome ? kIncomeCategories : kExpenseCategories;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final o in options)
              ListTile(
                leading: CategoryTile(
                  category: o,
                  type: r.isIncome ? TxnType.income : TxnType.expense,
                  size: 36,
                ),
                title: Text(o),
                trailing: o == r.category
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(c).pop(o),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _rows = [..._rows]..[i] = r.copyWith(category: picked);
    });
  }

  Future<void> _save() async {
    final tenantId = ref.read(currentTenantIdProvider);
    final userId = ref.read(currentUserIdProvider);
    if (tenantId == null || userId == null) {
      setState(() => _error = 'Sign in and pick a workspace first.');
      return;
    }
    if (!ref.read(isOnlineProvider)) {
      setState(() => _error = 'You\'re offline. Import needs a connection.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final out = await ref
          .read(importGatewayProvider)
          .importRows(tenantId: tenantId, userId: userId, rows: _chosen);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = out;
        _rows = const [];
        _sms.clear();
      });
      // Bring the new rows into the ledger.
      await ref.read(importRefreshProvider)();
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
    if (ref.watch(menuStatusProvider(FeatureMenu.import)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: 'Import',
        body: MenuLockedView(
          feature: 'Import',
          icon: Icons.file_upload_outlined,
        ),
      );
    }
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final palette = context.palette;
    final chosen = _chosen;
    final out = chosen
        .where((r) => !r.isIncome)
        .fold(Decimal.zero, (s, r) => s + r.amount);
    final inn = chosen
        .where((r) => r.isIncome)
        .fold(Decimal.zero, (s, r) => s + r.amount);

    return AppPage(
      title: 'Import',
      subtitle: 'From a spreadsheet, a bank statement or bank SMS',
      padBody: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.sm,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                if (!canWrite)
                  _Banner(
                    icon: Icons.visibility_outlined,
                    text: 'Your role in this workspace is view-only.',
                    color: palette.muted,
                  ),
                if (_done != null) _Result(_done!),
                if (_error != null)
                  _Banner(
                    icon: Icons.error_outline_rounded,
                    text: _error!,
                    color: Theme.of(context).colorScheme.error,
                  ),
                if (_rows.isEmpty) ...[
                  _SourceCard(
                    icon: Icons.table_chart_outlined,
                    title: 'From a file',
                    body:
                        'A CSV, Excel (.xlsx or .xls) or PDF file: the FinRoot '
                        'template, or a bank statement with Date, Narration '
                        'and Debit / Credit columns. Scanned PDFs can\'t be '
                        'read.',
                    actions: [
                      PillButton(
                        key: const ValueKey('import-pick-file'),
                        label: 'Choose a file',
                        icon: Icons.upload_file_rounded,
                        expand: true,
                        onPressed: canWrite ? _pickFile : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: _shareTemplate,
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Get the template'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _SourceCard(
                    icon: Icons.sms_outlined,
                    title: 'From bank SMS',
                    body:
                        'Copy payment alerts from your messages and paste '
                        'them here, with an empty line between messages. '
                        'Nothing is sent until you import.',
                    actions: [
                      TextField(
                        key: const ValueKey('import-sms'),
                        controller: _sms,
                        minLines: 4,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          hintText:
                              'Rs.1,250.00 debited from A/c XX1234 on '
                              '23-11-26 to SWIGGY. UPI Ref 1234…',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      PillButton(
                        label: 'Read messages',
                        icon: Icons.auto_awesome_rounded,
                        expand: true,
                        onPressed: canWrite && _sms.text.trim().isNotEmpty
                            ? _readSms
                            : null,
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    _source ?? '',
                    style: AppTypography.title.copyWith(color: palette.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${chosen.length} of ${_rows.length} selected · '
                    '${MoneyFormat.money(out.toDouble())} out · '
                    '${MoneyFormat.money(inn.toDouble())} in',
                    style: AppTypography.body.copyWith(color: palette.muted),
                  ),
                  if (_note != null && _note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _note!,
                      style: AppTypography.label.copyWith(color: palette.muted),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Untick anything you don\'t want. Tap a date or a '
                    'category to change it.',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _rows.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PreviewRow(
                            row: _rows[i],
                            on: !_off.contains(i),
                            onToggle: () => setState(() {
                              if (!_off.remove(i)) _off.add(i);
                            }),
                            onCategory: () => _pickCategory(i),
                            onDate: () => _pickDate(i),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_rows.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.sm,
                  AppSpacing.screenGutter,
                  AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PillButton(
                      key: const ValueKey('import-save'),
                      label: _busy
                          ? 'Importing…'
                          : 'Import ${chosen.length} transaction'
                                '${chosen.length == 1 ? '' : 's'}',
                      icon: Icons.check_rounded,
                      expand: true,
                      onPressed: _busy || chosen.isEmpty || !canWrite
                          ? null
                          : _save,
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _rows = const []),
                      child: const Text('Start over'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: AppTypography.body.copyWith(color: palette.muted)),
          const SizedBox(height: AppSpacing.lg),
          ...actions,
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.row,
    required this.on,
    required this.onToggle,
    required this.onCategory,
    required this.onDate,
  });
  final ImportRow row;
  final bool on;
  final VoidCallback onToggle;
  final VoidCallback onCategory;
  final VoidCallback onDate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final money = MoneyFormat.money(row.amount.toDouble());
    final type = row.isIncome ? TxnType.income : TxnType.expense;
    return Opacity(
      opacity: on ? 1 : 0.45,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Checkbox(value: on, onChanged: (_) => onToggle()),
              CategoryTile(category: row.category, type: type, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.description.isEmpty ? row.category : row.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        ActionChip(
                          key: const ValueKey('import-row-date'),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            DateFormat('d MMM yyyy').format(row.date),
                          ),
                          avatar: const Icon(Icons.event_rounded, size: 14),
                          onPressed: on ? onDate : null,
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(row.category),
                          avatar: const Icon(Icons.edit_rounded, size: 14),
                          onPressed: on ? onCategory : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                row.isIncome ? '+$money' : '-$money',
                style: AppTypography.bodyStrong.copyWith(
                  color: row.isIncome ? finance.income : finance.expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result(this.out);
  final ImportOutcome out;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final skipped = out.skipped;
    return _Banner(
      icon: Icons.check_circle_rounded,
      color: finance.income,
      text:
          'Added ${out.inserted} transaction${out.inserted == 1 ? '' : 's'}.'
          '${skipped > 0 ? ' $skipped ${skipped == 1 ? 'was' : 'were'} already in FinRoot and skipped.' : ''}',
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(color: context.palette.ink),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Asks for a protected PDF's (or Excel file's) password; pops it, or null
/// on Cancel.
class _PdfPasswordDialog extends StatefulWidget {
  const _PdfPasswordDialog({
    required this.name,
    required this.wrong,
    this.spreadsheet = false,
  });
  final String name;
  final bool wrong;
  final bool spreadsheet;

  @override
  State<_PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<_PdfPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _controller.text;
    if (p.isNotEmpty) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name;
    final wrong = widget.wrong;
    final what = widget.spreadsheet ? 'Excel file' : 'PDF';
    return AlertDialog(
      title: Text('Password-protected $what'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wrong
                ? 'That password didn\'t open $name. Check it and try again.'
                : '$name needs a password. Banks usually build it from your '
                      'details, such as your date of birth, PAN, customer ID '
                      'or the first letters of your name. The email with the '
                      'statement says which.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('import-pdf-password'),
            controller: _controller,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: '$what password',
              errorText: wrong ? 'Wrong password' : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Used only to open the file on this phone. It isn\'t saved.',
            style: AppTypography.label.copyWith(color: context.palette.muted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('import-pdf-password-open'),
          onPressed: _submit,
          child: const Text('Open'),
        ),
      ],
    );
  }
}
