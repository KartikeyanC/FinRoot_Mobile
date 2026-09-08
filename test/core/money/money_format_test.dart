import 'package:finroot_mobile/core/money/money_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyFormat.money', () {
    test('sign is outside the symbol', () {
      expect(MoneyFormat.money(-1240.5), '-₹1,240.5');
      expect(MoneyFormat.money(18600), '₹18,600');
    });

    test('Indian digit grouping (lakh/crore)', () {
      expect(MoneyFormat.money(120000), '₹1,20,000');
      expect(MoneyFormat.money(28400000), '₹2,84,00,000');
    });

    test('non-finite renders as em dash, never NaN', () {
      expect(MoneyFormat.money(double.nan), '—');
      expect(MoneyFormat.money(double.infinity), '—');
    });

    test('other currency symbols', () {
      expect(MoneyFormat.money(1000, currency: 'USD'), r'$1,000');
      expect(MoneyFormat.money(1000, currency: 'ZZZ'), '1,000');
    });
  });

  group('MoneyFormat.short', () {
    test('lakh / crore abbreviations', () {
      expect(MoneyFormat.short(284000), '₹2.84L');
      expect(MoneyFormat.short(12000000), '₹1.20Cr');
      expect(MoneyFormat.short(4500), '₹4.5k');
      expect(MoneyFormat.short(-284000), '-₹2.84L');
    });
  });
}
