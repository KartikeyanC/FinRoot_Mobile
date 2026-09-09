import '../../../core/money/money.dart';
import '../../../domain/constants.dart';

/// The three capture kinds Quick Add offers (brief §7). `transfer` is money
/// moving between the user's own accounts — no category, no payment mode, and
/// left out of every income/spend aggregate server-side.
enum QuickAddKind {
  expense,
  income,
  transfer;

  TxnType get txnType => switch (this) {
    QuickAddKind.expense => TxnType.expense,
    QuickAddKind.income => TxnType.income,
    QuickAddKind.transfer => TxnType.transfer,
  };

  String get label => switch (this) {
    QuickAddKind.expense => 'Expense',
    QuickAddKind.income => 'Income',
    QuickAddKind.transfer => 'Transfer',
  };

  /// Category list for the kind. Transfers have no category (they use the
  /// `Transfer` sentinel, matching the web's `TRANSFER_CATEGORY`).
  List<String> get categories => switch (this) {
    QuickAddKind.expense => kExpenseCategories,
    QuickAddKind.income => kIncomeCategories,
    QuickAddKind.transfer => const [],
  };
}

/// `transactions.category` value every transfer carries — must match the web's
/// `src/lib/transferMeta.ts` `TRANSFER_CATEGORY`.
const String kTransferCategory = 'Transfer';

/// Pure, testable validation for the Quick Add forms. Each returns a
/// user-facing message or `null` when the value is acceptable. The database
/// (and, once M1.5 is applied, the RPC) is still the real authority.
abstract final class QuickAddValidators {
  /// `numeric(14,2)` tops out here (web BR-023).
  static final Money _max = Money.parse('999999999999.99');

  static String? amount(String? raw) {
    final money = Money.tryParse(raw ?? '');
    if (money == null) return 'Enter an amount';
    if (!money.isPositive) return 'Amount must be more than zero';
    if (money > _max) return 'That amount is too large';
    return null;
  }

  static String? category(String? value, {required bool required}) {
    if (!required) return null;
    return (value == null || value.isEmpty) ? 'Pick a category' : null;
  }

  static String? note(String? value) {
    if (value != null && value.trim().length > 400) {
      return 'Keep the note under 400 characters';
    }
    return null;
  }

  static String? occurredAt(DateTime value, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    if (value.isAfter(ref.add(const Duration(minutes: 1)))) {
      return 'That date is in the future';
    }
    return null;
  }

  /// Source / destination account rules for a transfer.
  static String? transferAccounts({
    required String? fromId,
    required String? toId,
  }) {
    if (fromId == null) return 'Choose the account the money leaves';
    if (toId == null) return 'Choose the account the money arrives in';
    if (fromId == toId) return 'Pick two different accounts';
    return null;
  }
}
