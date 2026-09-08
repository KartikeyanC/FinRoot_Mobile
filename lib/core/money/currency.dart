/// Currencies and the FX table.
///
/// ⚠️ Mirrors `src/lib/finance.ts` in the FinRoot **web** repo verbatim. That
/// file is the single source of truth (web ADR-0008: one implementation per
/// rule). This copy exists only so the mobile client can render *cached /
/// optimistic* figures while offline. `test/core/money/fx_parity_test.dart`
/// pins these values against a fixture derived from the web file; if the web
/// table changes, that test fails and this file must be updated in the same PR.
///
/// V1 rule (web ADR / brief §41): spend and budget in INR. Transactions keep
/// their own currency; everything aggregates through [toInr].
library;

const String workspaceCurrency = 'INR';

const List<String> kCurrencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];

const Map<String, String> kCurrencySymbol = {
  'INR': '₹', // ₹
  'USD': '\$',
  'EUR': '€', // €
  'GBP': '£', // £
  'AED': 'د.إ', // د.إ
};

/// Rough FX → INR for cross-currency aggregation, display only. There is no FX
/// feed (web BR-025). Income streams / recurring items carry their own manual
/// rate server-side; this table is the fallback the web app also uses.
const Map<String, double> kFxToInr = {
  'INR': 1,
  'USD': 83.5,
  'EUR': 90,
  'GBP': 105,
  'AED': 22.7,
};

/// [amount] in [currency], converted to INR. Unknown currency → unchanged.
double toInr(num amount, String currency) =>
    amount.toDouble() * (kFxToInr[currency] ?? 1);

String currencySymbol(String currency) => kCurrencySymbol[currency] ?? '';
