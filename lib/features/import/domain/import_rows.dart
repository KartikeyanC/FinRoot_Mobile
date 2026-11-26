import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:decimal/decimal.dart';
import 'package:excel_plus/excel_plus.dart';

import '../../../domain/constants.dart';
import 'office_crypto.dart';
import 'sheet_text.dart';

/// Import, the phone half of the web's `TransactionImporter` (expenses /
/// income from a CSV or Excel file). Pure Dart so it is unit-tested on its
/// own (`test/features/import/import_rows_test.dart`).
///
/// It reads the web's own template (date, amount, category, description,
/// currency) and also a bank statement's usual columns: Debit / Credit
/// (or Withdrawal / Deposit) amounts and a Narration / Particulars text,
/// with dates written the Indian way (23/11/2026, 23-Nov-2026).
///
/// Every row carries the SAME `import_hash` the web builds
/// (`src/lib/importDedup.ts`): a file imported once on the phone and again on
/// the web — or twice anywhere — is stored once.
class ImportRow {
  const ImportRow({
    required this.date,
    required this.type,
    required this.amount,
    required this.category,
    this.description = '',
    this.currency = 'INR',
  });

  /// The calendar day (stored as UTC midnight, like the web's
  /// `new Date("2026-11-23")`).
  final DateTime date;

  /// `expense` or `income`.
  final String type;
  final Decimal amount;
  final String category;
  final String description;
  final String currency;

  bool get isIncome => type == 'income';

  ImportRow copyWith({String? category, String? type, DateTime? date}) =>
      ImportRow(
        date: date ?? this.date,
        type: type ?? this.type,
        amount: amount,
        category: category ?? this.category,
        description: description,
        currency: currency,
      );

  String get occurredAt =>
      DateTime.utc(date.year, date.month, date.day).toIso8601String();

  /// `src/lib/importDedup.ts` `canonicalImportKey`, byte for byte.
  String get canonicalKey {
    String norm(String s) => s.trim().toLowerCase();
    return [
      norm(type),
      amount.toStringAsFixed(2),
      norm(currency),
      norm(category),
      occurredAt.substring(0, 10),
      norm(description),
    ].join('|');
  }

  String get importHash => sha256.convert(utf8.encode(canonicalKey)).toString();
}

/// What a file gave: rows, how many lines had no amount, and how many had
/// an amount but a date that could not be read (left out rather than
/// guessed as today).
class ImportParse {
  const ImportParse(this.rows, this.skipped, {this.undated = 0});
  final List<ImportRow> rows;
  final int skipped;
  final int undated;
}

// Column names by meaning, in the shape [normaliseHeader] leaves them. A
// header matches a name exactly, as a plural, or when it starts with the
// name and a space ("withdrawal amt", "debit amount").
const _dateCols = [
  'date',
  'txn date',
  'transaction date',
  'tran date',
  'posting date',
  'value date',
  'value dt',
];
const _amountCols = ['amount', 'amt', 'transaction amount', 'txn amount'];
const _debitCols = ['debit', 'withdrawal', 'dr', 'dr amount', 'paid out'];
const _creditCols = ['credit', 'deposit', 'cr', 'cr amount', 'paid in'];
const _typeCols = ['type', 'transaction type', 'txn type', 'dr/cr', 'cr/dr'];
const _categoryCols = ['category'];
const _descCols = [
  'description',
  'note',
  'narration',
  'particulars',
  'remarks',
  'details',
  'transaction details',
  'transaction remarks',
  'transaction description',
];
const _currencyCols = ['currency'];

/// A header cell as the column lists spell it: lower case, without text in
/// brackets or currency marks, punctuation as spaces ("Withdrawal Amount
/// (INR )" → "withdrawal amount", "Deposit Amt." → "deposit amt").
String normaliseHeader(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp(r'\([^)]*\)'), ' ')
    .replaceAll(RegExp(r'₹|\binr\b|\brs\b'), ' ')
    .replaceAll(RegExp(r'[^a-z0-9/]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _headerIs(String header, String name) =>
    header == name || header == '${name}s' || header.startsWith('$name ');

/// What a header cell means to the importer, or null for a column it
/// ignores (balance, cheque number).
enum ImportColumn {
  date,
  amount,
  debit,
  credit,
  type,
  category,
  desc,
  currency,
}

ImportColumn? importColumnOf(String rawHeader) {
  final h = normaliseHeader(rawHeader);
  bool any(List<String> names) => names.any((n) => _headerIs(h, n));
  if (any(_dateCols)) return ImportColumn.date;
  if (any(_amountCols)) return ImportColumn.amount;
  if (any(_debitCols)) return ImportColumn.debit;
  if (any(_creditCols)) return ImportColumn.credit;
  if (any(_typeCols)) return ImportColumn.type;
  if (any(_categoryCols)) return ImportColumn.category;
  if (any(_descCols)) return ImportColumn.desc;
  if (any(_currencyCols)) return ImportColumn.currency;
  return null;
}

/// Whether a header cell is one known column name, maybe with a unit word
/// after it ("Withdrawal Amt.", "Debit Amount"), and not a name followed by
/// another column's ("Date Narration") — used to tell apart header words
/// printed close together in a PDF.
bool isExactImportHeader(String raw) {
  const units = {'amt', 'amount', 'amounts', 'dt', 'date', 'no', 'details'};
  final h = normaliseHeader(raw);
  if (h.isEmpty) return false;
  for (final names in const [
    _dateCols,
    _amountCols,
    _debitCols,
    _creditCols,
    _typeCols,
    _categoryCols,
    _descCols,
    _currencyCols,
  ]) {
    for (final n in names) {
      if (h == n || h == '${n}s') return true;
      if (h.startsWith('$n ') && units.contains(h.substring(n.length + 1))) {
        return true;
      }
    }
  }
  return false;
}

/// Whether a row of header cells names a date and an amount, debit or
/// credit column — what [parseImportTable] needs to call it the header.
bool isImportHeader(Iterable<String> cells) {
  final kinds = {for (final c in cells) importColumnOf(c)};
  return kinds.contains(ImportColumn.date) &&
      (kinds.contains(ImportColumn.amount) ||
          kinds.contains(ImportColumn.debit) ||
          kinds.contains(ImportColumn.credit));
}

/// Web `EXPENSE_CATEGORY_ALIASES` (`src/lib/importParsers.ts`).
const _expenseAliases = {
  'food': 'Food & Dining',
  'dining': 'Food & Dining',
  'food and dining': 'Food & Dining',
  'health': 'Healthcare',
  'medical': 'Healthcare',
  'health care': 'Healthcare',
  'transportation': 'Transport',
  'personal care': 'Personal Care',
  'subscription': 'Subscriptions',
  'utility': 'Utilities',
};

/// Web `canonicalExpenseCategory`.
String canonicalCategory(String raw, {required bool income}) {
  final key = raw.trim().toLowerCase();
  final list = income ? kIncomeCategories : kExpenseCategories;
  for (final c in list) {
    if (c.toLowerCase() == key) return c;
  }
  if (!income && _expenseAliases.containsKey(key)) return _expenseAliases[key]!;
  final t = raw.trim();
  return t.isEmpty ? (income ? 'Other' : 'Uncategorized') : t;
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// A cell to a calendar day: ISO (2026-11-23), Indian day-first
/// (23/11/2026, 23-11-26, 23.11.2026), 23-Nov-2026 / 23 Nov 2026 /
/// 23rd Nov 26 / 23Nov2026, Nov 23, 2026, an Excel date, or an Excel serial
/// number. A time after the date is ignored. Null when it is not a date.
DateTime? parseImportDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return DateTime(v.year, v.month, v.day);
  if (v is DateCellValue) return DateTime(v.year, v.month, v.day);
  if (v is DateTimeCellValue) return DateTime(v.year, v.month, v.day);
  final s = '$v'.trim();
  if (s.isEmpty) return null;

  final serial = double.tryParse(s);
  if (serial != null) {
    // Excel day numbers (1 = 1900-01-01) for 1990..2100.
    if (serial > 32874 && serial < 73051) {
      final d = DateTime.utc(1899, 12, 30).add(Duration(days: serial.floor()));
      return DateTime(d.year, d.month, d.day);
    }
    return null;
  }

  DateTime? ok(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final r = DateTime(y, m, d);
    return r.month == m ? r : null;
  }

  int? mon(String name) => _months[name.toLowerCase().substring(0, 3)];

  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null) {
    return ok(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  m = RegExp(r'^(\d{1,2})[-/. ](\d{1,2})[-/. ](\d{4}|\d{2})(?!\d)')
      .firstMatch(s);
  if (m != null) {
    return ok(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  m = RegExp(
    r'^(\d{1,2})(?:st|nd|rd|th)?[-/ ]?([A-Za-z]{3})[A-Za-z]*\.?[-/ ,]*'
    r'(\d{4}|\d{2})(?!\d)',
  ).firstMatch(s);
  if (m != null) {
    final mo = mon(m[2]!);
    return mo == null ? null : ok(int.parse(m[3]!), mo, int.parse(m[1]!));
  }
  m = RegExp(
    r'^([A-Za-z]{3})[A-Za-z]*\.?[ -](\d{1,2})(?:st|nd|rd|th)?,?[ -]*'
    r'(\d{4}|\d{2})(?!\d)',
  ).firstMatch(s);
  if (m != null) {
    final mo = mon(m[1]!);
    return mo == null ? null : ok(int.parse(m[3]!), mo, int.parse(m[2]!));
  }
  return null;
}

/// "₹1,23,456.50", "Rs.500", "INR 1,250.00", "1,234 Dr", "(500)", "500.00-"
/// → a positive number; null when empty or zero.
Decimal? parseImportAmount(Object? v) {
  if (v == null) return null;
  if (v is num) return v == 0 ? null : Decimal.parse(v.abs().toString());
  if (v is DoubleCellValue) return parseImportAmount(v.value);
  if (v is IntCellValue) return parseImportAmount(v.value);
  // Currency marks go first, so the dot of "Rs." can't become a decimal
  // point ("Rs.500" is 500, not 0.50).
  final s = '$v'
      .toLowerCase()
      .replaceAll(RegExp(r'₹|\binr\b|\brs\b\.?'), ' ')
      .replaceAll(RegExp(r'[^0-9.]'), '');
  if (s.isEmpty || s == '.') return null;
  final d = Decimal.tryParse(s);
  if (d == null || d == Decimal.zero) return null;
  return d;
}

/// Which way a signed amount cell points: -1 for "-500", "(500)", "500-" or
/// "500 Dr"; 1 for "500 Cr"; 0 when it doesn't say.
int _signOf(Object? v) {
  if (v is num) return v < 0 ? -1 : 0;
  if (v is DoubleCellValue) return _signOf(v.value);
  if (v is IntCellValue) return _signOf(v.value);
  final s = '$v'.trim().toLowerCase();
  if (s.isEmpty) return 0;
  if (s.endsWith('cr')) return 1;
  if (s.startsWith('-') ||
      s.endsWith('-') ||
      s.startsWith('(') ||
      s.endsWith('dr')) {
    return -1;
  }
  return 0;
}

String _text(Object? v) {
  if (v == null) return '';
  if (v is TextCellValue) return v.value.toString().trim();
  if (v is CellValue) return v.toString().trim();
  return '$v'.trim();
}

/// Turns a table into rows. The header is the row, among the first 30, that
/// names the most known columns (bank statements put account details above
/// the table) and has a date and an amount, debit or credit column; with
/// none, the first row with two or more filled cells. [defaultType] is used
/// when a row says nothing about direction.
ImportParse parseImportTable(
  List<List<Object?>> table, {
  String defaultType = 'expense',
}) {
  List<String> headerOf(List<Object?> r) => [
    for (final c in r) normaliseHeader(_text(c)),
  ];
  int colIn(List<String> header, List<String> names) {
    for (final n in names) {
      final i = header.indexWhere((h) => _headerIs(h, n));
      if (i >= 0) return i;
    }
    return -1;
  }

  const kinds = [
    _dateCols,
    _amountCols,
    _debitCols,
    _creditCols,
    _typeCols,
    _categoryCols,
    _descCols,
    _currencyCols,
  ];
  var headerAt = -1;
  var bestScore = 0;
  for (var i = 0; i < table.length && i < 30; i++) {
    final h = headerOf(table[i]);
    if (colIn(h, _dateCols) < 0) continue;
    if (colIn(h, _amountCols) < 0 &&
        colIn(h, _debitCols) < 0 &&
        colIn(h, _creditCols) < 0) {
      continue;
    }
    final score = kinds.where((names) => colIn(h, names) >= 0).length;
    if (score > bestScore) {
      bestScore = score;
      headerAt = i;
    }
  }
  if (headerAt < 0) {
    headerAt = table.indexWhere(
      (r) => r.where((c) => _text(c).isNotEmpty).length >= 2,
    );
  }
  if (headerAt < 0) return const ImportParse([], 0);
  final header = headerOf(table[headerAt]);
  int col(List<String> names) => colIn(header, names);

  final cDate = col(_dateCols);
  final cAmount = col(_amountCols);
  final cDebit = col(_debitCols);
  final cCredit = col(_creditCols);
  final cType = col(_typeCols);
  final cCat = col(_categoryCols);
  final cDesc = col(_descCols);
  final cCur = col(_currencyCols);
  Object? at(List<Object?> r, int i) => i >= 0 && i < r.length ? r[i] : null;

  final body = table.skip(headerAt + 1).toList();
  // One signed Amount column and nothing else saying which way money went:
  // when some amounts are negative, the positive ones are money in.
  final signed =
      cType < 0 &&
      cDebit < 0 &&
      cCredit < 0 &&
      body.any((r) => _signOf(at(r, cAmount)) < 0);

  final rows = <ImportRow>[];
  var skipped = 0;
  var undated = 0;
  for (final r in body) {
    if (r.every((c) => _text(c).isEmpty)) continue;
    final date = parseImportDate(at(r, cDate));
    Decimal? amount;
    var type = defaultType;
    final debit = parseImportAmount(at(r, cDebit));
    final credit = parseImportAmount(at(r, cCredit));
    if (debit != null) {
      amount = debit;
      type = 'expense';
    } else if (credit != null) {
      amount = credit;
      type = 'income';
    } else {
      final cell = at(r, cAmount);
      amount = parseImportAmount(cell);
      final t = _text(at(r, cType)).toLowerCase();
      final sign = _signOf(cell);
      if (t.startsWith('inc') || t == 'cr' || t.startsWith('credit')) {
        type = 'income';
      } else if (t.startsWith('exp') || t == 'dr' || t.startsWith('debit')) {
        type = 'expense';
      } else if (sign > 0) {
        type = 'income'; // "500 Cr"
      } else if (sign < 0) {
        type = 'expense';
      } else if (signed) {
        type = 'income';
      }
    }
    if (amount == null) {
      skipped++;
      continue;
    }
    if (date == null) {
      // Never guess today: an undated row would land in the wrong month.
      undated++;
      continue;
    }
    final income = type == 'income';
    rows.add(
      ImportRow(
        date: date,
        type: type,
        amount: amount,
        category: canonicalCategory(_text(at(r, cCat)), income: income),
        description: _text(at(r, cDesc)),
        currency: _text(at(r, cCur)).isEmpty
            ? 'INR'
            : _text(at(r, cCur)).toUpperCase(),
      ),
    );
  }
  return ImportParse(rows, skipped, undated: undated);
}

/// A CSV file's bytes to a table (UTF-8, with or without a BOM).
List<List<Object?>> csvTable(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return [for (final List<dynamic> r in Csv().decode(text)) r.cast<Object?>()];
}

/// A workbook that is password-protected: no password was given, or
/// [wrongPassword] when the one given didn't open it.
class ProtectedSpreadsheetException implements Exception {
  const ProtectedSpreadsheetException({this.wrongPassword = false});
  final bool wrongPassword;
}

/// A workbook protected in a way the importer can't open: Information
/// Rights Management, a certificate, an encryption add-in, or a cipher it
/// doesn't do ([detail], e.g. "DES encryption").
class UnsupportedSpreadsheetProtectionException implements Exception {
  const UnsupportedSpreadsheetProtectionException(this.kind, [this.detail]);
  final OfficeEncryption kind;
  final String? detail;

  /// What to tell the user about [fileName]: what the protection is, and
  /// that saving it from Excel without a password fixes it.
  String message(String fileName) {
    final what = switch (kind) {
      OfficeEncryption.irm =>
        '$fileName is protected with Information Rights Management (a '
            'sensitivity label or Restrict Access), which FinRoot can\'t open.',
      OfficeEncryption.certificate =>
        '$fileName is encrypted with a digital certificate instead of a '
            'password, which FinRoot can\'t open.',
      OfficeEncryption.extensible =>
        '$fileName is encrypted by a third-party encryption add-in, which '
            'FinRoot can\'t open.',
      _ when detail != null =>
        '$fileName is protected with $detail, which FinRoot can\'t open.',
      _ => '$fileName uses a kind of encryption FinRoot can\'t open.',
    };
    return kind == OfficeEncryption.irm
        ? '$what Open it in Excel and save a copy without the restriction or '
              'a password, then import that copy.'
        : '$what Open it in Excel and save it without a password, then '
              'import it again.';
  }

  @override
  String toString() =>
      'UnsupportedSpreadsheetProtectionException($kind'
      '${detail == null ? '' : ', $detail'})';
}

/// [bytes] with any password protection taken off, using [password]. With
/// no password, Excel's built-in one is tried first, so a workbook that is
/// only protected (no password to open) imports without asking, as it opens
/// in Excel.
List<int> _unlocked(List<int> bytes, String? password) {
  if (officeEncryptionOf(bytes) == OfficeEncryption.none) return bytes;
  try {
    if (password == null || password.isEmpty) {
      try {
        return decryptOfficeFile(bytes, officeDefaultPassword);
      } on OfficeWrongPasswordException {
        throw const ProtectedSpreadsheetException();
      }
    }
    return decryptOfficeFile(bytes, password);
  } on OfficeWrongPasswordException {
    throw const ProtectedSpreadsheetException(wrongPassword: true);
  } on OfficeUnsupportedEncryptionException catch (e) {
    throw UnsupportedSpreadsheetProtectionException(e.kind, e.detail);
  }
}

/// A spreadsheet cell as a plain value; a formula gives the result Excel
/// saved with it.
Object? _plainCell(CellValue? v) => switch (v) {
  null => null,
  TextCellValue() => v.value.toString(),
  IntCellValue() => v.value,
  DoubleCellValue() => v.value,
  DateCellValue() => DateTime(v.year, v.month, v.day),
  DateTimeCellValue() => DateTime(v.year, v.month, v.day),
  BoolCellValue() => v.value,
  FormulaCellValue(:final cachedValue) =>
    cachedValue == null ? null : (num.tryParse(cachedValue) ?? cachedValue),
  CellErrorValue() => null,
  _ => v.toString(),
};

/// The first non-empty sheet of an Excel file: .xlsx, or a legacy
/// Excel 97–2003 .xls (BIFF8). A password-protected file is opened with
/// [password] (only for this call; it isn't kept); without one, or with the
/// wrong one, it throws [ProtectedSpreadsheetException].
List<List<Object?>> xlsxTable(List<int> bytes, {String? password}) {
  final Excel book;
  try {
    book = Excel.decodeBytes(_unlocked(bytes, password));
  } on ExcelException catch (e) {
    if ('$e'.toLowerCase().contains('password')) {
      throw const ProtectedSpreadsheetException();
    }
    rethrow;
  }
  for (final sheet in book.tables.values) {
    final rows = [
      for (final r in sheet.rows) [for (final c in r) _plainCell(c?.value)],
    ];
    if (rows.any((r) => r.any((c) => c != null))) return rows;
  }
  return const [];
}

/// An `.xls` file: a real Excel 97–2003 workbook, or what banks often send
/// under that name instead — an .xlsx, an HTML table or tab-separated text.
List<List<Object?>> xlsTable(List<int> bytes, {String? password}) {
  const ole2 = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
  bool startsWith(List<int> sig) =>
      bytes.length >= sig.length &&
      [for (var i = 0; i < sig.length; i++) bytes[i] == sig[i]].every((b) => b);
  // A compound file (real .xls, or a protected .xlsx) or a zip ("PK",
  // really .xlsx).
  if (startsWith(ole2) || startsWith(const [0x50, 0x4B])) {
    return xlsxTable(bytes, password: password);
  }
  return textTableFromXlsName(bytes) ?? csvTable(bytes);
}

/// Drops rows that repeat inside one import (the web's `withImportHashes`).
({List<ImportRow> rows, int duplicates}) dedupeInFile(List<ImportRow> rows) {
  final seen = <String>{};
  final out = <ImportRow>[];
  for (final r in rows) {
    if (seen.add(r.importHash)) out.add(r);
  }
  return (rows: out, duplicates: rows.length - out.length);
}

/// The template the screen shares — the web's own column names.
const kImportTemplateCsv =
    'date,type,amount,category,description,currency\n'
    '2026-11-01,expense,450,Food & Dining,Lunch with team,INR\n'
    '2026-11-01,income,85000,Salary,November salary,INR\n';
