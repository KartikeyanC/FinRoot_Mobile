import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/bill_scan/domain/scan_result.dart';
import 'package:finroot_mobile/features/bill_scan/domain/scanned_row.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parity with the web `billScan.test.ts` — the mobile port of
/// `rowsFromScanResult` / `buildApprovalTransaction` / `reconcileTotal` /
/// `partitionRows` must behave the same.
Money _inr(String v) => Money(Decimal.parse(v));

ScanResult _receipt({
  List<ScanTaxLine>? taxLines,
  Money? total,
  bool noDate = false,
}) => ScanResult(
  merchant: 'Oudh 1590',
  currency: 'INR',
  date: noDate ? null : DateTime(2021, 2, 13),
  subtotal: _inr('1860'),
  total: total ?? _inr('1953'),
  items: [
    ScanItem(
      name: 'Biryani',
      qty: 2,
      unit: 'pc',
      amount: _inr('790'),
      category: 'Food & Dining',
    ),
    ScanItem(
      name: 'Galawati Kabab',
      qty: 1,
      unit: 'pc',
      amount: _inr('350'),
      category: 'Food & Dining',
    ),
    ScanItem(
      name: 'Roghan Josh',
      qty: 1,
      unit: 'pc',
      amount: _inr('340'),
      category: 'Food & Dining',
    ),
    ScanItem(
      name: 'Phirni',
      qty: 3,
      unit: 'pc',
      amount: _inr('270'),
      category: 'Food & Dining',
    ),
    ScanItem(
      name: 'Sikanji',
      qty: 1,
      unit: 'pc',
      amount: _inr('110'),
      category: 'Food & Dining',
    ),
  ],
  taxLines:
      taxLines ??
      [
        ScanTaxLine(label: 'CGST 2.5%', amount: _inr('46.5')),
        ScanTaxLine(label: 'SGST 2.5%', amount: _inr('46.5')),
      ],
);

final _today = DateTime(2021, 2, 13);

void main() {
  group('rowsFromScanResult', () {
    test('line-item mode: one row per item + one per tax line, not merged', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      expect(rows, hasLength(7));
      expect(rows.take(5).map((r) => r.name), [
        'Biryani',
        'Galawati Kabab',
        'Roghan Josh',
        'Phirni',
        'Sikanji',
      ]);
      expect(rows[0].kind, ScanRowKind.item);
      expect(rows[5].kind, ScanRowKind.tax);
      expect(rows[5].name, 'CGST 2.5%');
      expect(rows[6].name, 'SGST 2.5%');
    });

    test('keeps a Round Off line separate', () {
      final r = _receipt(
        taxLines: [
          ScanTaxLine(label: 'CGST', amount: _inr('46.5')),
          ScanTaxLine(label: 'SGST', amount: _inr('46.5')),
          ScanTaxLine(label: 'Round Off', amount: _inr('-0.4')),
        ],
      );
      final rows = rowsFromScanResult(r, ScanMode.lineItem, _today);
      expect(rows, hasLength(8));
      expect(rows[7].name, 'Round Off');
    });

    test('skips tax rows entirely when there is no tax', () {
      final rows = rowsFromScanResult(
        _receipt(taxLines: const []),
        ScanMode.lineItem,
        _today,
      );
      expect(rows, hasLength(5));
    });

    test('lumpsum uses the receipt stated total, not a re-sum', () {
      final rows = rowsFromScanResult(
        _receipt(total: _inr('1999')),
        ScanMode.lumpsum,
        _today,
      );
      expect(rows, hasLength(1));
      expect(rows.single.amount.amount.toDouble(), 1999);
      expect(rows.single.name, 'Oudh 1590');
    });

    test('falls back to today when the receipt has no date', () {
      final rows = rowsFromScanResult(
        _receipt(noDate: true),
        ScanMode.lumpsum,
        _today,
      );
      expect(rows.single.date, _today);
    });
  });

  group('buildApprovalTransaction — always ONE transaction', () {
    test('collapses every item + tax row into one amount', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      final a = buildApprovalTransaction(rows, 'Oudh 1590')!;
      expect(a.amount.amount.toDouble(), 1953);
      expect(a.category, 'Food & Dining');
      expect(a.description, 'Oudh 1590');
    });

    test('reflects a correction made during review', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      rows[0] = rows[0].copyWith(amount: _inr('700'));
      final a = buildApprovalTransaction(rows, 'Oudh 1590')!;
      expect(a.amount.amount.toDouble(), 1863); // 1953 - 90
    });

    test('reflects a removed row', () {
      final rows = rowsFromScanResult(
        _receipt(),
        ScanMode.lineItem,
        _today,
      ).sublist(1);
      final a = buildApprovalTransaction(rows, 'Oudh 1590')!;
      expect(a.amount.amount.toDouble(), 1163); // 1953 - 790
    });

    test('picks the majority category on a genuine mix', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      rows[0] = rows[0].copyWith(category: 'Shopping');
      expect(
        buildApprovalTransaction(rows, 'Oudh 1590')!.category,
        'Food & Dining',
      );
    });

    test('falls back to the first row name with no merchant', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lumpsum, _today);
      expect(buildApprovalTransaction(rows, '')!.description, rows.first.name);
    });

    test('null on empty rows', () {
      expect(buildApprovalTransaction(const [], 'x'), isNull);
    });
  });

  group('Reconciliation', () {
    test('matches within tolerance', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      final r = Reconciliation.of(rows, _inr('1953'));
      expect(r.matches, isTrue);
      expect(r.diff.amount.toDouble(), 0);
    });

    test('flags a real gap', () {
      final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
      final r = Reconciliation.of(rows, _inr('2100'));
      expect(r.matches, isFalse);
      expect(r.diff.amount.toDouble(), -147);
    });
  });

  test('partitionRows separates items from tax lines', () {
    final rows = rowsFromScanResult(_receipt(), ScanMode.lineItem, _today);
    final p = partitionRows(rows);
    expect(p.items, hasLength(5));
    expect(p.taxes.map((t) => t.name), ['CGST 2.5%', 'SGST 2.5%']);
  });

  group('planBillExpenses — the split options', () {
    List<ScannedRow> mixed() => [
      ScannedRow(
        name: 'Rice 5kg',
        category: 'Groceries',
        amount: _inr('450'),
        date: _today,
        kind: ScanRowKind.item,
      ),
      ScannedRow(
        name: 'Detergent',
        category: 'Household',
        amount: _inr('210'),
        date: _today,
        kind: ScanRowKind.item,
      ),
      ScannedRow(
        name: 'Dal 1kg',
        category: 'Groceries',
        amount: _inr('140'),
        date: _today,
        kind: ScanRowKind.item,
      ),
      ScannedRow(
        name: 'GST',
        category: 'Groceries',
        amount: _inr('10'),
        date: _today,
        kind: ScanRowKind.tax,
      ),
    ];

    test('one expense is the whole bill', () {
      final p = planBillExpenses(mixed(), 'DMart');
      expect(p, hasLength(1));
      expect(p.single.amount, _inr('810'));
      expect(p.single.category, 'Groceries');
      expect(p.single.description, 'DMart');
    });

    test('by category: one expense per category, items named', () {
      final p = planBillExpenses(
        mixed(),
        'DMart',
        mode: BillSaveMode.byCategory,
      );
      expect(p.map((e) => e.category), ['Groceries', 'Household']);
      expect(p[0].amount, _inr('600')); // 450 + 140 + 10 tax
      expect(p[0].description, 'DMart · Rice 5kg, Dal 1kg');
      expect(p[1].amount, _inr('210'));
      expect(p[1].description, 'DMart · Detergent');
    });

    test('split with people: only your share is logged', () {
      final one = planBillExpenses(mixed(), 'DMart', people: 3);
      expect(one.single.amount, _inr('270'));
      expect(one.single.description, 'DMart (your share, split 3 ways)');

      final each = planBillExpenses(
        mixed(),
        'DMart',
        mode: BillSaveMode.byCategory,
        people: 4,
      );
      expect(each[0].amount, _inr('150'));
      expect(each[1].amount, _inr('52.5'));
    });

    test('shares round to the paisa', () {
      expect(shareOf(_inr('100'), 3), _inr('33.33'));
      expect(shareOf(_inr('100'), 1), _inr('100'));
    });
  });
}
