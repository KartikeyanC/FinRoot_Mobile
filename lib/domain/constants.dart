/// Value lists that mirror the FinRoot **web** repo. Category is not a table
/// (M1 audit §5): these strings are what land in `transactions.category`,
/// `budgets.bucket`, `goals.category`, `trackers.type`. They must match the web
/// seed lists exactly or a mobile-created row renders as "unknown" on the web.
///
/// Sources:
/// - `src/lib/finance.ts` — INCOME_CATEGORIES, EXPENSE_CATEGORIES, BUDGET_BUCKETS, GOAL_CATEGORIES
/// - `src/lib/trackers.ts` — TRACKER_TYPES
/// - `src/lib/accessMenus.ts` — ACCESS_MENUS ids
///
/// Custom categories/subcategories additionally come from the tenant's
/// `tenant_settings` JSON at runtime (wired in a later phase).
library;

/// `transactions.type` CHECK. `transfer` is excluded from every income/expense
/// aggregate (web: inflating both corrupts the savings rate).
enum TxnType {
  income,
  expense,
  transfer;

  String get wire => name;
  static TxnType fromWire(String v) =>
      TxnType.values.firstWhere((t) => t.name == v);
}

const List<String> kIncomeCategories = [
  'Salary',
  'Freelance',
  'Business',
  'Investment',
  'Rental',
  'Dividend',
  'Interest',
  'Other',
];

const List<String> kExpenseCategories = [
  'Food & Dining',
  'Transport',
  'Shopping',
  'Healthcare',
  'Education',
  'Travel',
  'Subscriptions',
  'Utilities',
  'Rent',
  'Personal Care',
  'Entertainment',
  'Other',
];

const List<String> kBudgetBuckets = [
  'Needs',
  'Financial Freedom',
  'Education',
  'Play',
  'Long-Term Savings',
  'Giving',
  'Agri',
];

const List<String> kGoalCategories = [
  'Emergency Fund',
  'Insurance',
  'Travel',
  'Education',
  'Vehicle',
  'Home',
  'Retirement',
  'Gadget',
  'Other',
];

const List<String> kTrackerTypes = [
  'Home Construction',
  'Travel',
  'Wedding',
  'Vehicle',
  'Education',
  'Business Project',
  'Event',
  'Custom',
];

const List<String> kPaymentModes = [
  'UPI',
  'Cash',
  'Card',
  'Net Banking',
  'Wallet',
  'Cheque',
];

/// Feature menu ids — mirrors `all_feature_menus()` / `src/lib/accessMenus.ts`.
/// `get_effective_menus(tenant_id)` decides which are active. `dashboard`,
/// `income`, `expenses` are effectively always-on; `transactions`/`accounts`
/// are never gated server-side.
enum FeatureMenu {
  dashboard,
  income,
  expenses,
  investments,
  budget,
  goals,
  reminders,
  calculator,
  billScan('bill-scan'),
  import('import'),
  export('export'),
  insurance,
  netWorth('net-worth'),
  trips,
  trackers,
  billing;

  const FeatureMenu([this._wire]);
  final String? _wire;
  String get id => _wire ?? name;
}

/// "T-" is a DISPLAY convention only (web BR-077). The stored tracker name is
/// always the real one.
String trackerDisplayLabel(String name) => 'T-${name.trim()}';
