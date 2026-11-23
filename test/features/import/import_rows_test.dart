import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the duplicate key matches the web byte for byte', () {
    final r = ImportRow(
      date: DateTime(2026, 11),
      type: 'expense',
      amount: Decimal.parse('450'),
      category: 'Food & Dining',
      description: ' Lunch with team ',
    );
    expect(r.occurredAt, '2026-11-01T00:00:00.000Z');
    expect(
      r.canonicalKey,
      'expense|450.00|inr|food & dining|2026-11-01|lunch with team',
    );
    // sha256 of that key, computed with Node's crypto (= the web's).
    expect(
      r.importHash,
      '71a3ec995220960f68d2cc35a1277c09fbec7162f59af14bb8b040918b1fb6e1',
    );
  });

  test("reads the web's own template", () {
    final p = parseImportTable(csvTable(utf8.encode(kImportTemplateCsv)));
    expect(p.skipped, 0);
    expect(p.rows, hasLength(2));
    expect(p.rows[0].type, 'expense');
    expect(p.rows[0].category, 'Food & Dining');
    expect(p.rows[1].type, 'income');
    expect(p.rows[1].category, 'Salary');
    expect(p.rows[1].amount, Decimal.parse('85000'));
  });

  test('reads a bank statement: debit / credit, narration, Indian dates', () {
    const csv =
        '﻿HDFC Bank statement,,,,\n'
        'Date,Narration,Withdrawal Amt.,Deposit Amt.,Closing Balance\n'
        '23/11/26,UPI-SWIGGY-123,"1,250.00",,"10,000.00"\n'
        '22-Nov-2026,NEFT SALARY,,"85,000.00","11,250.00"\n'
        ',,,,\n'
        'Opening balance,,,,\n';
    final p = parseImportTable(csvTable(utf8.encode(csv)));
    expect(p.rows, hasLength(2));
    expect(p.rows[0].date, DateTime(2026, 11, 23));
    expect(p.rows[0].type, 'expense');
    expect(p.rows[0].amount, Decimal.parse('1250'));
    expect(p.rows[0].description, 'UPI-SWIGGY-123');
    expect(p.rows[0].category, 'Uncategorized');
    expect(p.rows[1].type, 'income');
    expect(p.rows[1].category, 'Other');
    expect(p.skipped, 1); // "Opening balance" has no date and no amount
  });

  test('category aliases follow the web', () {
    expect(canonicalCategory('food', income: false), 'Food & Dining');
    expect(canonicalCategory('MEDICAL', income: false), 'Healthcare');
    expect(canonicalCategory('salary', income: true), 'Salary');
    expect(canonicalCategory('Pets', income: false), 'Pets');
  });

  test('dates and amounts in the shapes statements use', () {
    expect(parseImportDate('2026-11-23'), DateTime(2026, 11, 23));
    expect(parseImportDate('23.11.2026'), DateTime(2026, 11, 23));
    expect(parseImportDate('23 Nov 2026'), DateTime(2026, 11, 23));
    expect(parseImportDate('46349'), DateTime(2026, 11, 23)); // Excel serial
    expect(parseImportDate('31/02/2026'), isNull);
    expect(parseImportDate('hello'), isNull);
    expect(parseImportAmount('₹1,23,456.50'), Decimal.parse('123456.5'));
    expect(parseImportAmount('-500'), Decimal.parse('500'));
    expect(parseImportAmount(''), isNull);
  });

  test('repeats inside one file are dropped once', () {
    final p = parseImportTable(
      csvTable(
        utf8.encode(
          'date,amount,category\n2026-11-01,100,Food\n2026-11-01,100,food\n',
        ),
      ),
    );
    final d = dedupeInFile(p.rows);
    expect(d.rows, hasLength(1));
    expect(d.duplicates, 1);
  });
}
