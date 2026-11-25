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

  test('more date shapes', () {
    final want = DateTime(2026, 11, 23);
    for (final d in [
      '23-11-26',
      '23 11 2026',
      '23Nov2026',
      '23rd Nov 2026',
      '23-Nov-26',
      'Nov 23, 2026',
      'November 23 2026',
      '23/11/2026 14:05:00',
      '2026/11/23',
    ]) {
      expect(parseImportDate(d), want, reason: d);
    }
  });

  test('amounts with currency marks and Dr / Cr', () {
    expect(parseImportAmount('Rs.500'), Decimal.parse('500'));
    expect(parseImportAmount('Rs. 1,250.00'), Decimal.parse('1250'));
    expect(parseImportAmount('INR 2,000'), Decimal.parse('2000'));
    expect(parseImportAmount('1,234.50 Dr'), Decimal.parse('1234.5'));
    expect(parseImportAmount('(500)'), Decimal.parse('500'));
    expect(parseImportAmount('500.00-'), Decimal.parse('500'));
    expect(parseImportAmount('Rs. 0.00'), isNull);
  });

  test('headers are matched loosely', () {
    expect(normaliseHeader('Withdrawal Amount (INR )'), 'withdrawal amount');
    expect(normaliseHeader('Deposit Amt.'), 'deposit amt');
    expect(normaliseHeader('Txn Date'), 'txn date');
  });

  test('an ICICI-style statement with account details above the table', () {
    const csv =
        'Account Number,XXXXXXXX1234\n'
        'Account Name,R KUMAR\n'
        'Statement Period,01/11/2026 to 23/11/2026\n'
        '\n'
        'S No.,Value Date,Transaction Date,Cheque Number,Transaction Remarks,'
        'Withdrawal Amount (INR ),Deposit Amount (INR ),Balance (INR )\n'
        '1,03/11/2026,03/11/2026,,UPI/ZOMATO,"Rs. 450.00",0.00,"9,550.00"\n'
        '2,05/11/2026,05/11/2026,,NEFT/SALARY,0.00,"85,000.00","94,550.00"\n'
        '3,not a date,,,CHARGES,10.00,0.00,"94,540.00"\n';
    final p = parseImportTable(csvTable(utf8.encode(csv)));
    expect(p.rows, hasLength(2));
    expect(p.rows[0].date, DateTime(2026, 11, 3));
    expect(p.rows[0].type, 'expense');
    expect(p.rows[0].amount, Decimal.parse('450'));
    expect(p.rows[0].description, 'UPI/ZOMATO');
    expect(p.rows[1].type, 'income');
    expect(p.rows[1].amount, Decimal.parse('85000'));
    // A row whose date can't be read is left out, not dated today.
    expect(p.undated, 1);
  });

  test('a single signed amount column: negatives out, positives in', () {
    const csv =
        'Date,Description,Amount\n'
        '01/11/2026,Rent,-15000\n'
        '02/11/2026,Refund,1200\n';
    final p = parseImportTable(csvTable(utf8.encode(csv)));
    expect(p.rows.map((r) => r.type), ['expense', 'income']);
  });

  test('Dr / Cr written after the amount', () {
    const csv =
        'Date,Particulars,Amount\n'
        '01/11/2026,ATM,"2,000.00 Dr"\n'
        '02/11/2026,Interest,"120.00 Cr"\n';
    final p = parseImportTable(csvTable(utf8.encode(csv)));
    expect(p.rows.map((r) => r.type), ['expense', 'income']);
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
