import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:decimal/decimal.dart';
import 'package:excel/excel.dart';

import '../../../domain/constants.dart';

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

  ImportRow copyWith({String? category, String? type}) => ImportRow(
    date: date,
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

/// What a file gave: rows, and how many lines had no date and no amount.
class ImportParse {
  const ImportParse(this.rows, this.skipped);
  final List<ImportRow> rows;
  final int skipped;
}

// Column names, lower-cased, by meaning.
const _dateCols = [
  'date',
  'txn date',
  'transaction date',
  'value date',
  'tran date',
  'posting date',
];
const _amountCols = ['amount', 'amt', 'amount (inr)', 'transaction amount'];
const _debitCols = [
  'debit',
  'withdrawal',
  'withdrawal amt.',
  'withdrawal amount',
  'dr',
  'debit amount',
];
const _creditCols = [
  'credit',
  'deposit',
  'deposit amt.',
  'deposit amount',
  'cr',
  'credit amount',
];
const _typeCols = ['type', 'transaction type', 'dr/cr', 'cr/dr'];
const _categoryCols = ['category'];
const _descCols = [
  'description',
  'note',
  'notes',
  'narration',
  'particulars',
  'remarks',
  'details',
  'transaction details',
];
const _currencyCols = ['currency'];

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
/// (23/11/2026, 23-11-26, 23.11.2026), 23-Nov-2026 / 23 Nov 2026, an Excel
/// date, or an Excel serial number. Null when it is not a date.
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

  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null) {
    return ok(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(s);
  if (m != null) {
    return ok(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  }
  m = RegExp(r'^(\d{1,2})[-/ ]([A-Za-z]{3})[A-Za-z]*[-/ ,]+(\d{2,4})')
      .firstMatch(s);
  if (m != null) {
    final mon = _months[m[2]!.toLowerCase()];
    return mon == null ? null : ok(int.parse(m[3]!), mon, int.parse(m[1]!));
  }
  return null;
}

/// "₹1,23,456.50", "1,234 Dr", "(500)" → a positive number; null when empty.
Decimal? parseImportAmount(Object? v) {
  if (v == null) return null;
  if (v is num) return v == 0 ? null : Decimal.parse(v.abs().toString());
  if (v is DoubleCellValue) return parseImportAmount(v.value);
  if (v is IntCellValue) return parseImportAmount(v.value);
  final s = '$v'.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (s.isEmpty || s == '-' || s == '.') return null;
  final d = Decimal.tryParse(s);
  if (d == null || d == Decimal.zero) return null;
  return d < Decimal.zero ? -d : d;
}

String _text(Object? v) {
  if (v == null) return '';
  if (v is TextCellValue) return v.value.toString().trim();
  if (v is CellValue) return v.toString().trim();
  return '$v'.trim();
}

/// Turns a table (first row with two or more filled cells = the header) into
/// rows. [defaultType] is used when a row says nothing about direction.
ImportParse parseImportTable(
  List<List<Object?>> table, {
  String defaultType = 'expense',
}) {
  final headerAt = table.indexWhere(
    (r) => r.where((c) => _text(c).isNotEmpty).length >= 2,
  );
  if (headerAt < 0) return const ImportParse([], 0);
  final header = [for (final c in table[headerAt]) _text(c).toLowerCase()];
  int col(List<String> names) {
    for (final n in names) {
      final i = header.indexOf(n);
      if (i >= 0) return i;
    }
    return -1;
  }

  final cDate = col(_dateCols);
  final cAmount = col(_amountCols);
  final cDebit = col(_debitCols);
  final cCredit = col(_creditCols);
  final cType = col(_typeCols);
  final cCat = col(_categoryCols);
  final cDesc = col(_descCols);
  final cCur = col(_currencyCols);
  Object? at(List<Object?> r, int i) => i >= 0 && i < r.length ? r[i] : null;

  final rows = <ImportRow>[];
  var skipped = 0;
  for (final r in table.skip(headerAt + 1)) {
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
      amount = parseImportAmount(at(r, cAmount));
      final t = _text(at(r, cType)).toLowerCase();
      if (t.startsWith('inc') || t == 'cr' || t.startsWith('credit')) {
        type = 'income';
      } else if (t.startsWith('exp') || t == 'dr' || t.startsWith('debit')) {
        type = 'expense';
      } else if (cType < 0 && '${at(r, cAmount)}'.trim().startsWith('-')) {
        type = 'expense';
      }
    }
    if (date == null && amount == null) {
      skipped++;
      continue;
    }
    if (amount == null) {
      skipped++;
      continue;
    }
    final income = type == 'income';
    rows.add(
      ImportRow(
        // The web stores "today" for a row whose date it cannot read.
        date: date ?? DateTime.now(),
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
  return ImportParse(rows, skipped);
}

/// A CSV file's bytes to a table (UTF-8, with or without a BOM).
List<List<Object?>> csvTable(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return [for (final List<dynamic> r in Csv().decode(text)) r.cast<Object?>()];
}

/// The first non-empty sheet of an .xlsx file.
List<List<Object?>> xlsxTable(List<int> bytes) {
  final book = Excel.decodeBytes(bytes);
  for (final sheet in book.tables.values) {
    final rows = [
      for (final r in sheet.rows) [for (final c in r) c?.value],
    ];
    if (rows.any((r) => r.any((c) => c != null))) return rows;
  }
  return const [];
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
