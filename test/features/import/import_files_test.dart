import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:flutter_test/flutter_test.dart';

// The fixtures were saved by Excel 2016: the same bank statement as
// "Excel 97-2003 Workbook" (.xls) and as .xlsx, a sheet of 600 long
// strings (half with ₹, so the .xls string table spills into CONTINUE
// records in both 8- and 16-bit form), and a .xls with an open password.
List<int> _fixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

void main() {
  for (final name in ['statement.xls', 'statement.xlsx']) {
    test('$name: bank details above the header, dates, formulas', () {
      final table = name.endsWith('.xls')
          ? xlsTable(_fixture(name))
          : xlsxTable(_fixture(name));
      expect(table[0][0], 'HDFC BANK Ltd.');
      expect(table[5][2], '0000123'); // text, leading zeros kept
      expect(table[6][6], 95000); // a formula's saved result

      final p = parseImportTable(table);
      expect(p.rows.map((r) => r.description), [
        'UPI-SWIGGY-ORDER',
        'NEFT CR-ACME PAYROLL',
        'ATM WDL',
        'UPI-SWIGGY-ORDER',
      ]);
      expect(p.rows.map((r) => r.date), [
        DateTime(2026, 11),
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 4),
      ]);
      expect(p.rows.map((r) => r.type), [
        'expense',
        'income',
        'expense',
        'expense',
      ]);
      expect(p.rows.map((r) => r.amount), [
        Decimal.parse('450.5'),
        Decimal.parse('85000'),
        Decimal.parse('1000'), // =200*5
        Decimal.parse('1250'), // "Rs.1,250.00" as text
      ]);
      expect(p.undated, 1); // "31/13/26"
      expect(p.skipped, 1); // a formula giving text, no amount
    });
  }

  test('.xls shared strings across CONTINUE records', () {
    final t = xlsTable(_fixture('long_strings.xls'));
    expect(t, hasLength(600));
    for (var r = 0; r < 600; r++) {
      final n = r.toString().padLeft(4, '0');
      expect(
        t[r][0],
        r.isEven
            ? 'Narration $n paid to a merchant with a long name'
            : 'Narration $n paid ₹ to a merchant with a long name',
      );
    }
  });

  test('a password-protected .xls says so', () {
    expect(
      () => xlsTable(_fixture('protected.xls')),
      throwsA(isA<ProtectedSpreadsheetException>()),
    );
  });

  test('.xls names that hold an HTML table or tab-separated text', () {
    const html =
        '<html><body><table><tr><td>Bank</td></tr>'
        '<tr><th>Txn Date</th><th>Description</th><th>Debit</th>'
        '<th>Credit</th></tr>'
        '<tr><td>05/11/2026</td><td>UPI&nbsp;ZOMATO</td><td>1,200.00</td>'
        '<td></td></tr></table></body></html>';
    var p = parseImportTable(xlsTable(utf8.encode(html)));
    expect(p.rows.single.description, 'UPI ZOMATO');
    expect(p.rows.single.amount, Decimal.parse('1200'));

    const tsv =
        'Date\tNarration\tWithdrawal\tDeposit\n06/11/2026\tSALARY\t\t5000\n';
    p = parseImportTable(xlsTable(utf8.encode(tsv)));
    expect(p.rows.single.type, 'income');
  });
}
