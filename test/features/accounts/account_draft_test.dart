import 'package:finroot_mobile/features/accounts/domain/account_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('name is required and length-bounded', () {
    expect(AccountValidators.name(''), isNotNull);
    expect(AccountValidators.name('   '), isNotNull);
    expect(AccountValidators.name('x' * 81), isNotNull);
    expect(AccountValidators.name('SBI Savings'), isNull);
  });

  test('opening balance is optional, parses, and may be negative', () {
    expect(AccountValidators.openingBalance(null), isNull);
    expect(AccountValidators.openingBalance(''), isNull);
    expect(AccountValidators.openingBalance('not money'), isNotNull);
    expect(AccountValidators.openingBalance('-15000'), isNull); // credit card
    expect(AccountValidators.openingBalance('1,20,000.50'), isNull);
    expect(AccountValidators.openingBalance('999999999999999'), isNotNull);
  });

  test('every account type has a label', () {
    for (final type in kAccountTypes) {
      expect(accountTypeLabel(type), isNotEmpty);
    }
    expect(accountTypeLabel('mystery'), 'Other');
  });
}
