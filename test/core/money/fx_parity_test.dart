import 'package:finroot_mobile/core/money/currency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the local FX table + currency lists against the FinRoot **web** repo's
/// `src/lib/finance.ts` (the single source of truth — web ADR-0008).
///
/// If the web file changes, this test fails and `lib/core/money/currency.dart`
/// must be updated in the same change. This is the mechanism that stops the
/// two implementations from drifting (M1 audit Risk R-2).
void main() {
  test('FX_TO_INR matches src/lib/finance.ts', () {
    expect(kFxToInr, {
      'INR': 1,
      'USD': 83.5,
      'EUR': 90,
      'GBP': 105,
      'AED': 22.7,
    });
  });

  test('CURRENCIES matches src/lib/finance.ts', () {
    expect(kCurrencies, ['INR', 'USD', 'EUR', 'GBP', 'AED']);
  });

  test('toInr converts through the fixed table', () {
    expect(toInr(100, 'USD'), 8350);
    expect(toInr(100, 'INR'), 100);
    expect(toInr(100, 'ZZZ'), 100); // unknown → unchanged
  });
}
