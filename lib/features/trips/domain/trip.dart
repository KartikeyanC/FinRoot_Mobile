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
  /// Optional keys are left out when empty (the web writes `undefined`).
  Map<String, dynamic> toJson() => {
    ...raw,
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
    this.archivedAt,
  });

  final String id;
  final String name;

  /// `solo` | `friends` | `family` | `other`.
  final String kind;
  final String startDate;
  final int days;
  final List<String> companions;

  /// accountId → allocated amount (₹).
  final Map<String, double> allocation;
  final List<TripExpense> expenses;

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
    required this.remaining,
    required this.spentByAccount,
    required this.remainingByAccount,
  });

  final double allocated;
  final double spent;
  final double remaining;
  final Map<String, double> spentByAccount;
  final Map<String, double> remainingByAccount;

  /// Web `tripTotals`.
  factory TripTotals.of(Trip trip) {
    final allocated = trip.allocation.values.fold(0.0, (s, n) => s + n);
    final spentBy = <String, double>{};
    var spent = 0.0;
    for (final e in trip.expenses) {
      spentBy[e.accountId] = (spentBy[e.accountId] ?? 0) + e.amount;
      spent += e.amount;
    }
    return TripTotals(
      allocated: allocated,
      spent: spent,
      remaining: allocated - spent < 0 ? 0 : allocated - spent,
      spentByAccount: spentBy,
      remainingByAccount: {
        for (final e in trip.allocation.entries)
          e.key: e.value - (spentBy[e.key] ?? 0),
      },
    );
  }
}

/// The trip's settle-up transfers (web TripSettleUp: none for solo trips).
List<Transfer> tripTransfers(Trip trip) {
  if (trip.isSolo) return const [];
  return settleUp(
    tripSettleExpenses([
      for (final e in trip.expenses)
        (amount: e.amount, paidBy: e.paidBy, splitWith: e.splitWith),
    ]),
  );
}

/// Build a new expense item the way the web's TripWorkspace does: `paidBy`
/// is written only on a shared trip, and a companion who paid is always one
/// of the sharers.
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
  final shared = trip.isShared;
  final payerIsFriend = shared && paidBy != kTripPayerYou;
  final sharers = payerIsFriend && !splitWith.contains(paidBy)
      ? [...splitWith, paidBy]
      : splitWith;
  final trimmed = note?.trim();
  return TripExpense(
    id: 'exp_${t.millisecondsSinceEpoch}',
    amount: amount,
    accountId: accountId,
    category: category,
    note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    at: t.toUtc().toIso8601String(),
    splitWith: trip.isSolo ? null : sharers,
    paidBy: shared ? paidBy : null,
  );
}
