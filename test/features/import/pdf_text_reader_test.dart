import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/import/data/pdf_text_reader.dart';
import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:finroot_mobile/features/import/domain/pdf_statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

// Real PDFium on the test machine (pdfrx's build hook bundles it). The
// fixtures: statement.xlsx printed to PDF by Excel; the same with the open
// password "ABCD0101" (AES-128, made with PyMuPDF); and that page as a
// picture only, like a scan.
List<int> _fixture(String name) =>
    File('test/fixtures/import/$name').readAsBytesSync();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await pdfrxInitialize(tmpPath: Directory.systemTemp.createTempSync().path);
  });

  Future<ImportParse> parse(List<PdfWord> words) async =>
      parseImportTable(pdfStatementTable(pdfLines(words)));

  test(
    'an Excel-printed statement reads like the .xlsx it came from',
    () async {
      final p = await parse(await readPdfWords(_fixture('statement.pdf')));
      expect(p.rows.map((r) => r.description), [
        'UPI-SWIGGY-ORDER',
        'NEFT CR-ACME PAYROLL',
        'ATM WDL',
        'UPI-SWIGGY-ORDER',
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
        Decimal.parse('1000'),
        Decimal.parse('1250'),
      ]);
      expect(p.rows.last.date, DateTime(2026, 11, 4));
      expect(p.undated, 1);
    },
  );

  test('a protected PDF: no password, a wrong one, the right one', () async {
    final bytes = _fixture('statement_protected.pdf');
    await expectLater(
      readPdfWords(bytes),
      throwsA(
        isA<PdfReadException>().having(
          (e) => e.problem,
          'problem',
          PdfReadProblem.needsPassword,
        ),
      ),
    );
    await expectLater(
      readPdfWords(bytes, password: 'abcd0101'),
      throwsA(
        isA<PdfReadException>().having(
          (e) => e.problem,
          'problem',
          PdfReadProblem.wrongPassword,
        ),
      ),
    );
    final p = await parse(await readPdfWords(bytes, password: 'ABCD0101'));
    expect(p.rows, hasLength(4));
  });

  test('a scanned PDF has no text', () async {
    await expectLater(
      readPdfWords(_fixture('statement_scanned.pdf')),
      throwsA(
        isA<PdfReadException>().having(
          (e) => e.problem,
          'problem',
          PdfReadProblem.noText,
        ),
      ),
    );
  });
}
