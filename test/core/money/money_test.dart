import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parse and storage string keep 2dp exactly (no double drift)', () {
    final m = Money.parse('18600.10');
    expect(m.toStorageString(), '18600.10');
    expect(m.amount, Decimal.parse('18600.10'));
  });

  test('tryParse strips symbols, grouping and whitespace', () {
    expect(Money.tryParse('  ₹1,240.50 ')!.toStorageString(), '1240.50');
    expect(Money.tryParse('abc'), isNull);
    expect(Money.tryParse(''), isNull);
  });

  test('addition of large amounts stays exact', () {
    final total = Money.parse('99999999.99') + Money.parse('0.01');
    expect(total.toStorageString(), '100000000.00');
  });

  test('same-currency comparison', () {
    expect(Money.parse('10') < Money.parse('10.01'), isTrue);
  });

  test('cross-currency arithmetic trips an assert in debug', () {
    expect(
      () => Money(Decimal.one, 'USD') + Money(Decimal.one),
      throwsA(isA<AssertionError>()),
    );
  });
}
