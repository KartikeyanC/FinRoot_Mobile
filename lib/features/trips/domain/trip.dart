import '../../../core/money/currency.dart';
import '../../split/domain/split_dues.dart';

/// Trips — the web's `trips` table (src/lib/tripsStore.ts). A trip is a jsonb
/// sandbox: its expenses live in `trips.expenses` and are read by no
/// aggregate (dashboard, budget, net worth). Nothing here ever writes to
/// `transactions`.

/// `trips.kind`.
const kTripKindLabels = {
  'solo': 'Solo trip',
  'friends': 'Friends trip',
  'family': 'Family trip',
  'other': 'Other',
};

/// Trip spend categories (web tripMeta.CATEGORIES).
const kTripCategories = [
  'Food',
  'Stay',
  'Travel',
  'Activity',
  'Shopping',
  'Other',
];

/// The virtual cash account id (web `CASH_ACCOUNT_ID`).
const kTripCashAccountId = '_cash';

/// Most companions a trip keeps (web NewTripDialog `.slice(0, 6)`).
const kTripMaxCompanions = 6;

/// A stored currency code, or INR when it is missing or malformed (web
/// `tripCurrencyOf`). Trips made before `trips.currency` existed are INR.
String tripCurrencyOf(Object? raw) {
  final c = raw is String ? raw.trim().toUpperCase() : '';
  return RegExp(r'^[A-Z]{3}$').hasMatch(c) ? c : 'INR';
}

/// Currencies a trip can be kept in — the app's own list.
const List<String> kTripCurrencies = kCurrencies;

/// One item of `trips.expenses`. [raw] keeps every key as stored, so writing
/// the array back never drops a field another app version added.
class TripExpense {
  const TripExpense({
    required this.id,
    required this.amount,
    required this.accountId,
    required this.category,
    required this.at,
    this.note,
    this.splitWith,
    this.paidBy,
    this.raw = const {},
  });

  final String id;
  final double amount;

  /// The account it was paid from; empty when a companion paid (no money
  /// left any of your accounts — web TripWorkspace).
  final String accountId;
  final String category;
  final String? note;

  /// ISO datetime.
  final String at;
  final List<String>? splitWith;

  /// `"you"` ([kTripPayerYou]) or a companion's name; missing = you.
  final String? paidBy;
  final Map<String, dynamic> raw;

  /// The settle-up name of whoever paid.
  String get payer => tripPayerName(paidBy);

  /// You paid it (old items without `paidBy` included).
  bool get paidByYou => payer == kMe;

  factory TripExpense.fromJson(Map<String, dynamic> j) => TripExpense(
    id: (j['id'] ?? '').toString(),
    amount: switch (j['amount']) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    },
    accountId: (j['accountId'] as String?) ?? kTripCashAccountId,
    category: (j['category'] as String?) ?? 'Other',
    note: j['note'] as String?,
    at: (j['at'] as String?) ?? '',
    splitWith: (j['splitWith'] as List?)?.map((e) => e.toString()).toList(),
    paidBy: j['paidBy'] as String?,
    raw: j,
  );

  /// The jsonb item: the stored keys, overlaid with this item's fields.
  /// Optional keys are left out when empty (the web writes `undefined`), so
  /// clearing a note on an edit really clears it.
  Map<String, dynamic> toJson() => {
    for (final e in raw.entries)
      if (!const {'note', 'splitWith', 'paidBy'}.contains(e.key))
        e.key: e.value,
    'id': id,
    'amount': amount,
    'accountId': accountId,
    'category': category,
    'at': at,
    if (note != null && note!.isNotEmpty) 'note': note,
    if (splitWith != null) 'splitWith': splitWith,
    if (paidBy != null) 'paidBy': paidBy,
  };
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    required this.kind,
    required this.startDate,
    required this.days,
    required this.companions,
    required this.allocation,
    required this.expenses,
    required this.status,
    required this.createdAt,
    this.currency = 'INR',
    this.archivedAt,
  });

  final String id;
  final String name;

  /// `solo` | `friends` | `family` | `other`.
  final String kind;
  final String startDate;
  final int days;
  final List<String> companions;

  /// accountId → allocated amount, in [currency].
  final Map<String, double> allocation;
  final List<TripExpense> expenses;

  /// ISO 4217 code every amount of the trip is in (`trips.currency`).
  final String currency;

  /// `active` | `archived`.
  final String status;
  final String createdAt;
  final String? archivedAt;

  bool get isArchived => status == 'archived';
  bool get isSolo => kind == 'solo';

  /// Companions can share and pay (web TripWorkspace `shared`).
  bool get isShared => !isSolo && companions.isNotEmpty;

  String get kindLabel => kTripKindLabels[kind] ?? 'Trip';

  factory Trip.fromRow(Map<String, dynamic> r) {
    final alloc = <String, double>{};
    final rawAlloc = r['allocation'];
    if (rawAlloc is Map) {
      rawAlloc.forEach((k, v) {
        alloc[k.toString()] = switch (v) {
          final num n => n.toDouble(),
          final String s => double.tryParse(s) ?? 0,
          _ => 0,
        };
      });
    }
    final rawExp = r['expenses'];
    return Trip(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? 'Trip',
      kind: (r['kind'] as String?) ?? 'other',
      startDate: (r['start_date'] as String?) ?? '',
      days: switch (r['days']) {
        final num n => n.toInt(),
        _ => 0,
      },
      companions:
          (r['companions'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      allocation: alloc,
      expenses: rawExp is List
          ? [
              for (final e in rawExp)
                if (e is Map)
                  TripExpense.fromJson(Map<String, dynamic>.from(e)),
            ]
          : const [],
      currency: tripCurrencyOf(r['currency']),
      status: (r['status'] as String?) ?? 'active',
      createdAt: (r['created_at'] as String?) ?? '',
      archivedAt: r['archived_at'] as String?,
    );
  }
}

class TripTotals {
  const TripTotals({
    required this.allocated,
    required this.spent,
    required this.paidByYou,
    required this.remaining,
    required this.spentByAccount,
    required this.remainingByAccount,
  });

  final double allocated;

  /// The whole trip's spending, whoever paid.
  final double spent;

  /// What you paid: the only part that draws on your pool.
  final double paidByYou;
  final double remaining;
  final Map<String, double> spentByAccount;
  final Map<String, double> remainingByAccount;

  /// Web `tripTotals`: `spent` counts everyone; the pool, `remaining` and the
  /// per-account figures count only what you paid — a companion's payment
  /// never left your accounts.
  factory TripTotals.of(Trip trip) {
    final allocated = trip.allocation.values.fold(0.0, (s, n) => s + n);
    final spentBy = <String, double>{};
    var spent = 0.0;
    var yours = 0.0;
    for (final e in trip.expenses) {
      spent += e.amount;
      if (!e.paidByYou) continue;
      yours += e.amount;
      spentBy[e.accountId] = (spentBy[e.accountId] ?? 0) + e.amount;
    }
    return TripTotals(
      allocated: allocated,
      spent: spent,
      paidByYou: yours,
      remaining: allocated - yours < 0 ? 0 : allocated - yours,
      spentByAccount: spentBy,
      remainingByAccount: {
        for (final e in trip.allocation.entries)
          e.key: e.value - (spentBy[e.key] ?? 0),
      },
    );
  }
}

/// The trip's settle-up transfers (web TripSettleUp: none for solo trips), in
/// the trip's currency.
List<Transfer> tripTransfers(Trip trip) {
  if (trip.isSolo) return const [];
  return settleUp(
    tripSettleExpenses([
      for (final e in trip.expenses)
        (amount: e.amount, paidBy: e.paidBy, splitWith: e.splitWith),
    ], currency: trip.currency),
  );
}

/// Build a new expense item the way the web's TripWorkspace does: `paidBy`
/// is written only on a shared trip, a companion who paid is always one of
/// the sharers, and no account is stored when a companion paid.
TripExpense newTripExpense({
  required Trip trip,
  required double amount,
  required String accountId,
  required String category,
  required List<String> splitWith,
  required String paidBy,
  String? note,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  return _withFields(
    trip: trip,
    id: 'exp_${t.millisecondsSinceEpoch}',
    at: t.toUtc().toIso8601String(),
    raw: const {},
    amount: amount,
    accountId: accountId,
    category: category,
    splitWith: splitWith,
    paidBy: paidBy,
    note: note,
  );
}

/// [original] with its fields changed (an edit): same id, same time it was
/// logged, and every key another app version added kept.
TripExpense editedTripExpense({
  required Trip trip,
  required TripExpense original,
  required double amount,
  required String accountId,
  required String category,
  required List<String> splitWith,
  required String paidBy,
  String? note,
}) => _withFields(
  trip: trip,
  id: original.id,
  at: original.at,
  raw: original.raw,
  amount: amount,
  accountId: accountId,
  category: category,
  splitWith: splitWith,
  paidBy: paidBy,
  note: note,
);

TripExpense _withFields({
  required Trip trip,
  required String id,
  required String at,
  required Map<String, dynamic> raw,
  required double amount,
  required String accountId,
  required String category,
  required List<String> splitWith,
  required String paidBy,
  String? note,
}) {
  final shared = trip.isShared;
  final payerIsFriend = shared && paidBy != kTripPayerYou;
  final sharers = payerIsFriend && !splitWith.contains(paidBy)
      ? [...splitWith, paidBy]
      : splitWith;
  final trimmed = note?.trim();
  return TripExpense(
    id: id,
    amount: amount,
    accountId: payerIsFriend ? '' : accountId,
    category: category,
    note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    at: at,
    splitWith: trip.isSolo ? null : sharers,
    paidBy: shared ? paidBy : null,
    raw: raw,
  );
}

/* ------------------------------- writing ------------------------------- */

/// One add / edit / remove of a trip expense (web `ExpenseChange`).
sealed class TripExpenseChange {
  const TripExpenseChange();
}

class AddTripExpense extends TripExpenseChange {
  const AddTripExpense(this.expense);
  final TripExpense expense;
}

class UpdateTripExpense extends TripExpenseChange {
  const UpdateTripExpense(this.expense);
  final TripExpense expense;
}

class RemoveTripExpense extends TripExpenseChange {
  const RemoveTripExpense(this.id);
  final String id;
}

const String kTripExpenseGoneMessage = 'That expense was removed from the trip';

/// The array after one change — the same rules as the server's locked
/// trip_expense_* functions (web `applyExpenseChange`):
/// - add: newest first; an id already on the trip is left alone (a retry);
/// - update: replaces the item with the same id, in place; [StateError] if
///   it's gone;
/// - remove: drops it; removing one that's already gone changes nothing.
List<Map<String, dynamic>> applyTripExpenseChange(
  List<Map<String, dynamic>> list,
  TripExpenseChange change,
) {
  bool has(String id) => list.any((e) => e['id']?.toString() == id);
  switch (change) {
    case AddTripExpense(:final expense):
      return has(expense.id) ? list : [expense.toJson(), ...list];
    case UpdateTripExpense(:final expense):
      if (!has(expense.id)) throw StateError(kTripExpenseGoneMessage);
      return [
        for (final e in list)
          e['id']?.toString() == expense.id ? expense.toJson() : e,
      ];
    case RemoveTripExpense(:final id):
      return [
        for (final e in list)
          if (e['id']?.toString() != id) e,
      ];
  }
}

/// The RPC name and its arguments for one change.
({String fn, Map<String, dynamic> params}) tripExpenseRpcCall(
  String tripId,
  TripExpenseChange change,
) => switch (change) {
  AddTripExpense(:final expense) => (
    fn: 'trip_expense_add',
    params: {'p_trip_id': tripId, 'p_expense': expense.toJson()},
  ),
  UpdateTripExpense(:final expense) => (
    fn: 'trip_expense_update',
    params: {'p_trip_id': tripId, 'p_expense': expense.toJson()},
  ),
  RemoveTripExpense(:final id) => (
    fn: 'trip_expense_remove',
    params: {'p_trip_id': tripId, 'p_expense_id': id},
  ),
};

/// The trip_expense_* functions don't exist yet: migration 20261126150000
/// hasn't run (web `isTripExpenseRpcMissing`).
bool isTripExpenseRpcMissing({String? code, String? message}) {
  if (code == 'PGRST202' || code == '42883') return true;
  final m = message ?? '';
  return RegExp('trip_expense', caseSensitive: false).hasMatch(m) &&
      RegExp(
        'does not exist|schema cache|could not find',
        caseSensitive: false,
      ).hasMatch(m);
}

/// `trips.currency` doesn't exist yet (web `isTripCurrencyMissing`).
bool isTripCurrencyMissing({String? code, String? message}) {
  final m = message ?? '';
  return (code == 'PGRST204' ||
          code == '42703' ||
          RegExp(
            'could not find|does not exist',
            caseSensitive: false,
          ).hasMatch(m)) &&
      RegExp('currency', caseSensitive: false).hasMatch(m);
}

const String kTripCurrencyMissingMessage =
    'Trips in a currency other than INR need the database update '
    '(migration 20261126150000_trip_expenses.sql). Ask the workspace owner '
    'to run it, or keep this trip in INR.';

/* ----------------------- changing a trip's currency ---------------------- */
// Migration 20261126170000_trip_currency_change.sql adds trip_set_currency.

const String kTripCurrencyRpc = 'trip_set_currency';

/// What trip_set_currency stores: [amount] × [rate], to two decimals (web
/// `convertTripAmount`).
double convertTripAmount(double amount, double rate) =>
    (amount * rate * 100).round() / 100;

/// 1 [from] = this many [to], from the app's fixed rates ([kFxToInr]), to six
/// significant figures (web `suggestedTripRate`). A starting point only.
double suggestedTripRate(String from, String to) => double.parse(
  ((kFxToInr[from] ?? 1) / (kFxToInr[to] ?? 1)).toStringAsPrecision(6),
);

/// Why this change can't be saved, or null; [rate] null keeps the numbers.
/// The limits trip_set_currency applies (web `tripCurrencyChangeProblem`).
String? tripCurrencyChangeProblem(Trip trip, String to, double? rate) {
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(to)) return 'Pick a currency';
  if (to == trip.currency) return 'The trip is already in $to';
  if (rate == null) return null;
  if (!rate.isFinite || rate <= 0) return 'Enter a rate more than zero';
  if (rate >= 1e6) return 'That rate is too large. Check it';
  final spends = [
    for (final e in trip.expenses) convertTripAmount(e.amount, rate),
  ];
  final budget = [
    for (final n in trip.allocation.values) convertTripAmount(n, rate),
  ];
  if (spends.any((n) => n <= 0) ||
      [...spends, ...budget].any((n) => n >= 1e12)) {
    return 'At that rate an amount would round to zero or get too large. '
        'Check the rate';
  }
  return null;
}

/// trip_set_currency doesn't exist yet: migration 20261126170000 hasn't run
/// (web `isTripCurrencyRpcMissing`).
bool isTripCurrencyRpcMissing({String? code, String? message}) {
  if (code == 'PGRST202' || code == '42883') return true;
  final m = message ?? '';
  return RegExp('trip_set_currency', caseSensitive: false).hasMatch(m) &&
      RegExp(
        'does not exist|schema cache|could not find',
        caseSensitive: false,
      ).hasMatch(m);
}

const String kTripCurrencyConvertMissingMessage =
    "Converting a trip's amounts needs the database update (migration "
    '20261126170000_trip_currency_change.sql). Ask the workspace owner to '
    'run it, or keep the amounts as they are.';

/* ------------------------------ a new trip ----------------------------- */

/// What the phone's New trip form collects (web NewTripDialog).
class NewTrip {
  const NewTrip({
    required this.name,
    required this.kind,
    required this.days,
    required this.startDate,
    required this.companions,
    required this.allocation,
    this.currency = 'INR',
  });

  final String name;
  final String kind;
  final int days;
  final DateTime startDate;
  final List<String> companions;
  final Map<String, double> allocation;
  final String currency;

  /// Why it can't be saved yet, or null (web NewTripDialog `submit`).
  String? get problem {
    if (name.trim().isEmpty) return 'Give your trip a name';
    if (!kTripKindLabels.containsKey(kind)) return 'Pick a trip type';
    if (allocation.values.fold(0.0, (s, n) => s + n) <= 0) {
      return 'Allocate at least one funding source';
    }
    return null;
  }

  /// The `trips` row to insert. Companions are dropped on a solo trip and
  /// capped at [kTripMaxCompanions]; `currency` is sent only when it isn't
  /// INR, so INR trips save before migration 20261126150000 adds the column.
  Map<String, dynamic> toRow(String tenantId) {
    final seen = <String>{};
    final names = [
      if (kind != 'solo')
        for (final c in companions)
          if (c.trim().isNotEmpty &&
              c.trim() != kMe &&
              seen.add(c.trim().toLowerCase()))
            c.trim(),
    ].take(kTripMaxCompanions).toList();
    final ccy = tripCurrencyOf(currency);
    final d = startDate;
    return {
      'tenant_id': tenantId,
      'name': name.trim(),
      'kind': kind,
      'start_date':
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}',
      'days': days < 1 ? 1 : days,
      'companions': names,
      'allocation': {
        for (final e in allocation.entries)
          if (e.value > 0) e.key: e.value,
      },
      'expenses': const <Object>[],
      'status': 'active',
      if (ccy != 'INR') 'currency': ccy,
    };
  }
}

/// Companions typed as "Riya, Aman, Neha".
List<String> parseCompanions(String text) => [
  for (final s in text.split(','))
    if (s.trim().isNotEmpty) s.trim(),
];
