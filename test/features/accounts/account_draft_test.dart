import 'package:finroot_mobile/core/money/money.dart';
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

  group('opening date (web accounts.opening_date)', () {
    test('create writes the picked date as yyyy-MM-dd', () {
      final body = accountWriteBody(
        AccountDraft(
          name: ' SBI ',
          type: 'bank',
          openingBalance: Money.parse('1000'),
          openingDate: DateTime(2025, 3, 7, 18, 30),
        ),
        creating: true,
      );
      expect(body['opening_date'], '2025-03-07');
      expect(body['name'], 'SBI');
      expect(body['opening_balance'], 1000.0);
    });

    test('create with no date falls back to today', () {
      final body = accountWriteBody(
        const AccountDraft(name: 'Cash', type: 'cash'),
        creating: true,
        today: DateTime(2026, 11, 26),
      );
      expect(body['opening_date'], '2026-11-26');
    });

    test('edit with no date leaves the stored one alone', () {
      final body = accountWriteBody(
        const AccountDraft(name: 'Cash', type: 'cash'),
        creating: false,
      );
      expect(body.containsKey('opening_date'), isFalse);
    });

    test('edit with a date writes it', () {
      final body = accountWriteBody(
        AccountDraft(
          name: 'Cash',
          type: 'cash',
          openingDate: DateTime(2024, 1, 31),
        ),
        creating: false,
      );
      expect(body['opening_date'], '2024-01-31');
    });

    test('parses date and timestamp shapes, rejects junk', () {
      expect(parseAccountDate('2025-03-07'), DateTime(2025, 3, 7));
      expect(
        parseAccountDate('2025-03-07T00:00:00.000Z'),
        DateTime(2025, 3, 7),
      );
      expect(parseAccountDate(null), isNull);
      expect(parseAccountDate('soon'), isNull);
    });
  });
}
