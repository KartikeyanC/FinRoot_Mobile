import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/import/data/pdf_text_reader.dart';
import 'package:finroot_mobile/features/import/domain/import_rows.dart';
import 'package:finroot_mobile/features/import/domain/pdf_statement.dart';
import 'package:flutter_test/flutter_test.dart';

// A stand-in for what PDFium gives: every character 5pt wide, 10pt tall,
// one space between words. A cell is (left edge, text); [right] right-aligns
// it on that x instead, the way amounts are printed.
const _cw = 5.0;

List<PdfWord> _line(
  double y,
  List<(double, String)> cells, {
  int page = 1,
  Set<int> right = const {},
}) {
  final out = <PdfWord>[];
  for (var i = 0; i < cells.length; i++) {
    final (x0, text) = cells[i];
    var x = right.contains(i) ? x0 - text.length * _cw : x0;
    for (final w in text.split(' ')) {
      out.add(
        PdfWord(
          w,
          left: x,
          right: x + w.length * _cw,
          top: y,
          bottom: y + 10,
          page: page,
        ),
      );
      x += (w.length + 1) * _cw;
    }
  }
  return out;
}

// Column x positions of a statement in the HDFC layout.
const _date = 20.0;
const _narr = 80.0;
const _ref = 260.0;
const _valueDt = 330.0;
const _wdl = 470.0; // right edges of the amount columns
const _dep = 550.0;
const _bal = 640.0;

List<PdfWord> _header(double y, {int page = 1}) => _line(y, [
  (_date, 'Date'),
  (_narr, 'Narration'),
  (_ref, 'Chq./Ref.No.'),
  (_valueDt, 'Value Dt'),
  (400, 'Withdrawal Amt.'),
  (490, 'Deposit Amt.'),
  (570, 'Closing Balance'),
], page: page);

List<PdfWord> _txn(
  double y,
  String date,
  String narration, {
  String ref = '',
  String wdl = '',
  String dep = '',
  String bal = '',
  int page = 1,
}) => _line(
  y,
  [
    (_date, date),
    (_narr, narration),
    if (ref.isNotEmpty) (_ref, ref),
    (_valueDt, date),
    if (wdl.isNotEmpty) (_wdl, wdl),
    if (dep.isNotEmpty) (_dep, dep),
    if (bal.isNotEmpty) (_bal, bal),
  ],
  page: page,
  right: {
    // indexes of the amount cells, which are right-aligned
    for (var i = (ref.isNotEmpty ? 4 : 3); i < 7; i++) i,
  },
);

ImportParse _parse(List<PdfWord> words) =>
    parseImportTable(pdfStatementTable(pdfLines(words)));

void main() {
  test('an HDFC-style PDF statement: header below the bank details, '
      'wrapped narrations, a second page', () {
    final words = [
      ..._line(20, [(20, 'HDFC BANK Ltd.')]),
      ..._line(34, [(20, 'Account No : 50100012345678')]),
      ..._line(48, [(20, 'Statement From : 01/11/2026 To : 30/11/2026')]),
      ..._header(80),
      ..._txn(
        96,
        '01/11/26',
        'UPI-SWIGGY-SWIGGY8@ybl',
        ref: '0000123456',
        wdl: '450.00',
        bal: '9,550.00',
      ),
      // The narration wraps onto two more lines.
      ..._line(108, [(_narr, 'ORDER 98231-HDFC0000001')]),
      ..._line(120, [(_narr, 'PAYMENT FROM PHONE')]),
      ..._txn(
        136,
        '02/11/26',
        'NEFT CR-ACME PAYROLL',
        dep: '1,25,000.00',
        bal: '1,34,550.00',
      ),
      ..._txn(152, '31/13/26', 'BAD DATE ROW', wdl: '99.00'),
      // Totals at the bottom of page 1, then a page footer far below.
      ..._line(
        176,
        [(_narr, 'STATEMENT SUMMARY'), (_wdl, '549.00'), (_dep, '1,25,000.00')],
        right: {1, 2},
      ),
      ..._line(780, [(250, 'Page 1 of 2')]),
      // Page 2 repeats the header.
      ..._line(20, [(20, 'HDFC BANK Ltd.')], page: 2),
      ..._header(40, page: 2),
      ..._txn(56, '03/11/26', 'ATM WDL', wdl: '1,000.00', page: 2),
    ];
    final p = _parse(words);
    expect(p.rows.map((r) => r.description), [
      'UPI-SWIGGY-SWIGGY8@ybl ORDER 98231-HDFC0000001 PAYMENT FROM PHONE',
      'NEFT CR-ACME PAYROLL',
      'ATM WDL',
    ]);
    expect(p.rows.map((r) => r.date), [
      DateTime(2026, 11),
      DateTime(2026, 11, 2),
      DateTime(2026, 11, 3),
    ]);
    expect(p.rows.map((r) => r.type), ['expense', 'income', 'expense']);
    expect(p.rows.map((r) => r.amount), [
      Decimal.parse('450'),
      Decimal.parse('125000'),
      Decimal.parse('1000'),
    ]);
    expect(p.undated, 1);
    expect(p.skipped, 0);
  });

  test('a header that wraps, one signed Amount column with Dr / Cr', () {
    final words = [
      ..._line(20, [
        (20, 'Transaction'),
        (120, 'Particulars'),
        (420, 'Amount'),
      ]),
      ..._line(32, [(20, 'Date')]),
      ..._line(
        48,
        [(20, '05 Nov 2026'), (120, 'POS AMAZON'), (470, '1,200.00 Dr')],
        right: {2},
      ),
      ..._line(
        64,
        [(20, '06 Nov 2026'), (120, 'IMPS REFUND'), (470, '300.00 Cr')],
        right: {2},
      ),
    ];
    final table = pdfStatementTable(pdfLines(words));
    expect(table.first, ['Transaction Date', 'Particulars', 'Amount']);
    final p = parseImportTable(table);
    expect(p.rows.map((r) => r.type), ['expense', 'income']);
    expect(p.rows.map((r) => r.description), ['POS AMAZON', 'IMPS REFUND']);
    expect(p.rows[0].amount, Decimal.parse('1200'));
  });

  test('two columns printed close together are split by the header', () {
    // A long narration runs up to the right-aligned amount: the two are
    // one space apart, so they read as one run of words.
    final words = [
      ..._line(20, [(20, 'Date'), (90, 'Description'), (200, 'Debit')]),
      ..._line(36, [(20, '07/11/2026'), (90, 'UPI-OLA-RIDE-BENGALURU 250.00')]),
    ];
    final p = _parse(words);
    expect(p.rows.single.description, 'UPI-OLA-RIDE-BENGALURU');
    expect(p.rows.single.amount, Decimal.parse('250'));
  });

  test('header words printed as close as words of one name', () {
    // Positions as PDFium read them from an Excel-printed statement: the
    // header words touch or overlap, and amounts sit under them unaligned.
    PdfWord w(String t, double l, double r, double y) =>
        PdfWord(t, left: l, right: r, top: y, bottom: y + 9);
    final words = [
      w('Date', 54, 73, 100),
      w('Narration', 105, 145, 100),
      w('Chq./Ref.No.', 267, 323, 100),
      w('Value', 318, 342, 100),
      w('Dt', 346, 355, 100),
      w('Withdrawal', 370, 420, 100),
      w('Amt.', 422, 442, 100),
      w('Deposit', 422, 455, 100),
      w('Amt.', 457, 477, 100),
      w('Closing', 473, 506, 100),
      w('Balance', 509, 543, 100),
      w('01/11/26', 60, 100, 115),
      w('UPI-SWIGGY-ORDER', 105, 195, 115),
      w('0000123', 267, 305, 115),
      w('01/11/26', 326, 365, 115),
      w('450.5', 392, 417, 115),
      w('10000', 493, 520, 115),
      w('02/11/26', 60, 100, 130),
      w('NEFT', 105, 127, 130),
      w('CR-ACME', 130, 172, 130),
      w('PAYROLL', 175, 215, 130),
      w('02/11/26', 326, 365, 130),
      w('85000', 441, 468, 130),
      w('95000', 493, 520, 130),
    ];
    final table = pdfStatementTable(pdfLines(words));
    expect(table.first, [
      'Date',
      'Narration',
      'Chq./Ref.No.',
      'Value Dt',
      'Withdrawal Amt.',
      'Deposit Amt.',
      'Closing Balance',
    ]);
    final p = parseImportTable(table);
    expect(p.rows.map((r) => r.type), ['expense', 'income']);
    expect(p.rows.map((r) => r.amount), [
      Decimal.parse('450.5'),
      Decimal.parse('85000'),
    ]);
  });

  test('two amounts under one column are never run together', () {
    final words = [
      ..._line(20, [(20, 'Date'), (90, 'Particulars'), (200, 'Debit')]),
      // A stray second number lands under Debit too.
      ..._line(36, [(20, '08/11/2026'), (90, 'NACH'), (200, '500.00 12')]),
    ];
    final p = _parse(words);
    expect(p.rows.single.amount, Decimal.parse('500'));
  });

  test('no table header: nothing', () {
    final words = [
      ..._line(20, [(20, 'Dear customer, your statement is attached.')]),
      ..._line(36, [(20, '01/11/2026'), (200, '450.00')]),
    ];
    expect(pdfStatementTable(pdfLines(words)), isEmpty);
  });

  test('words on slightly different baselines share a line', () {
    final lines = pdfLines([
      const PdfWord('450.00', left: 300, right: 330, top: 101, bottom: 111),
      const PdfWord('01/11/26', left: 20, right: 60, top: 100, bottom: 110),
      const PdfWord('next', left: 20, right: 40, top: 115, bottom: 125),
    ]);
    expect(lines.map((l) => '$l'), ['01/11/26 450.00', 'next']);
  });

  test("PDFium's characters to words, top-down", () {
    // "AB 12\r\nC": PDF space has y going up from the bottom of a 800pt page.
    final boxes = <(double, double, double, double)>[
      (10, 790, 15, 780),
      (15, 790, 20, 780),
      (20, 790, 22, 780), // space
      (40, 790, 45, 780),
      (45, 790, 50, 780),
      (0, 0, 0, 0), // \r
      (0, 0, 0, 0), // \n
      (10, 770, 15, 760),
    ];
    final w = wordsFromChars('AB 12\r\nC', boxes, pageHeight: 800, page: 2);
    expect(w.map((x) => x.text), ['AB', '12', 'C']);
    expect(w[0].left, 10);
    expect(w[0].right, 20);
    expect(w[0].top, 10);
    expect(w[0].bottom, 20);
    expect(w[2].top, 30);
    expect(w.every((x) => x.page == 2), isTrue);
  });
}
