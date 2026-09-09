import 'package:finroot_mobile/features/bill_scan/domain/scan_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses the Edge Function shape', () {
    final r = ScanResult.fromJson({
      'merchant': 'Big Bazaar',
      'currency': 'INR',
      'date': '2026-09-02',
      'subtotal': 940.0,
      'total': 987.0,
      'items': [
        {
          'name': 'Milk 1L',
          'qty': 2,
          'unit': 'L',
          'unitPrice': 60,
          'amount': 120,
          'category': 'Groceries',
        },
      ],
      'taxLines': [
        {'label': 'CGST', 'amount': 23.5},
      ],
    });
    expect(r.merchant, 'Big Bazaar');
    expect(r.date, DateTime(2026, 9, 2));
    expect(r.total.amount.toDouble(), 987);
    expect(r.items.single.unit, 'L');
    // "Groceries" isn't a mobile category -> snapped
    expect(r.items.single.category, 'Food & Dining');
    expect(r.taxLines.single.amount.amount.toDouble(), 23.5);
  });

  test('missing/blank fields get safe defaults', () {
    final r = ScanResult.fromJson({
      'merchant': '',
      'total': 50,
      'items': [
        {'name': '', 'qty': 0, 'unit': 'bogus', 'amount': 50, 'category': ''},
      ],
      'taxLines': const <Object?>[],
    });
    expect(r.currency, 'INR');
    expect(r.date, isNull);
    expect(r.items.single.name, 'Item');
    expect(r.items.single.qty, 1);
    expect(r.items.single.unit, 'pc');
    expect(r.items.single.category, 'Other');
  });

  group('normalizeScanCategory', () {
    test('passes a real expense category through', () {
      expect(normalizeScanCategory('Transport'), 'Transport');
      expect(normalizeScanCategory('Rent'), 'Rent');
    });
    test('maps the known aliases', () {
      expect(normalizeScanCategory('Travel & Transport'), 'Transport');
      expect(normalizeScanCategory('Pharmacy'), 'Healthcare');
    });
    test('unknown -> Other', () {
      expect(normalizeScanCategory('Widgets'), 'Other');
      expect(normalizeScanCategory(null), 'Other');
    });
  });
}
