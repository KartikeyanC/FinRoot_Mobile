/// Split dues — who owes whom, from Split with friends and from Trips.
///
/// A Dart port of the web's pure `src/lib/splitDues.ts` (and the bits of
/// `src/components/expenses/smartSplitMath.ts` it needs), so both apps decide
/// money the same way. Money is worked in PAISE (integer hundredths) wherever
/// it is divided, so a three-way ₹100 is 33.34 + 33.33 + 33.33 and the parts
/// always add back to the whole. Currencies are never mixed.
///
/// A due is not a transaction: nothing here posts to the ledger, and trip
/// money stays in the trip's jsonb sandbox.
library;

/// `split_dues.direction`.
enum DueDirection {
  owedToMe('owed_to_me'),
  iOwe('i_owe');

  const DueDirection(this.wire);
  final String wire;

  static DueDirection fromWire(String? w) =>
      w == 'i_owe' ? DueDirection.iOwe : DueDirection.owedToMe;
}

/// `split_dues.source`.
enum DueSource {
  split('split'),
  trip('trip');

  const DueSource(this.wire);
  final String wire;

  static DueSource fromWire(String? w) =>
      w == 'trip' ? DueSource.trip : DueSource.split;
}

/// One `split_dues` row.
class SplitDue {
  const SplitDue({
    required this.id,
    required this.person,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.source,
    required this.createdAt,
    this.note,
    this.sourceId,
    this.settledAt,
    this.settledAmount = 0,
  });

  final String id;
  final String person;
  final double amount;
  final String currency;
  final DueDirection direction;
  final String? note;
  final DueSource source;
  final String? sourceId;
  final String createdAt;
  final String? settledAt;
  final double settledAmount;

  bool get isSettled => settledAt != null;

  factory SplitDue.fromRow(Map<String, dynamic> r) => SplitDue(
    id: r['id'] as String,
    person: (r['person'] as String?) ?? '',
    amount: _num(r['amount']),
    currency: (r['currency'] as String?) ?? 'INR',
    direction: DueDirection.fromWire(r['direction'] as String?),
    note: r['note'] as String?,
    source: DueSource.fromWire(r['source'] as String?),
    sourceId: r['source_id'] as String?,
    createdAt: (r['created_at'] as String?) ?? '',
    settledAt: r['settled_at'] as String?,
    settledAmount: _num(r['settled_amount']),
  );
}

double _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

/// A due about to be inserted.
class NewSplitDue {
  const NewSplitDue({
    required this.person,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.source,
    this.note,
    this.sourceId,
    this.settled = false,
  });

  final String person;
  final double amount;
  final String currency;
  final DueDirection direction;
  final DueSource source;
  final String? note;
  final String? sourceId;

  /// Record already closed (a trip settled on the spot).
  final bool settled;

  NewSplitDue copyWith({bool? settled}) => NewSplitDue(
    person: person,
    amount: amount,
    currency: currency,
    direction: direction,
    source: source,
    note: note,
    sourceId: sourceId,
    settled: settled ?? this.settled,
  );

  /// The insert body (web `useRecordSplitDues`).
  Map<String, dynamic> toInsert(String tenantId, DateTime now) => {
    'person': person,
    'amount': amount,
    'currency': currency,
    'direction': direction.wire,
    'source': source.wire,
    'note': note,
    'source_id': sourceId,
    'tenant_id': tenantId,
    'settled_amount': settled ? amount : 0,
    'settled_at': settled ? now.toUtc().toIso8601String() : null,
  };

  @override
  bool operator ==(Object other) =>
      other is NewSplitDue &&
      other.person == person &&
      other.amount == amount &&
      other.currency == currency &&
      other.direction == direction &&
      other.source == source &&
      other.note == note &&
      other.sourceId == sourceId &&
      other.settled == settled;

  @override
  int get hashCode => Object.hash(
    person,
    amount,
    currency,
    direction,
    source,
    note,
    sourceId,
    settled,
  );

  @override
  String toString() =>
      'NewSplitDue($person, $amount $currency, ${direction.wire}, '
      '${source.wire}, note: $note, source: $sourceId, settled: $settled)';
}

/// The name the trip/split math uses for the signed-in person.
const String kMe = 'You';

int toPaise(num n) => (n * 100).round();
double fromPaise(int p) => p / 100;

/// Split [totalPaise] into [n] parts that sum exactly; the remainder goes to
/// the first parts.
List<int> splitPaise(int totalPaise, int n) {
  if (n <= 0) return const [];
  final base = totalPaise ~/ n;
  final extra = totalPaise - base * n;
  return [for (var i = 0; i < n; i++) base + (i < extra ? 1 : 0)];
}

int _cmpName(String a, String b) {
  // Close to JS localeCompare for plain names: case-insensitive first.
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  return c != 0 ? c : a.compareTo(b);
}

/* ------------------------------ Split with friends ------------------------------ */

/// Smart Split bucket kinds (web `smartSplitMath.Kind`).
enum AllocationKind { mine, office, shared }

/// Smart Split methods (web `SplitMode`).
enum SplitMode { amount, percent, shares }

/// One bucket of a split (web `Allocation`): a value for every method; the
/// active mode decides which one is the source of truth.
class Allocation {
  const Allocation({
    required this.id,
    required this.label,
    required this.kind,
    this.amount = '',
    this.pct = '',
    this.shares = '',
  });

  final String id;
  final String label;
  final AllocationKind kind;
  final String amount;
  final String pct;
  final String shares;
}

/// A blank or half-typed input is 0, never NaN.
double parseNum(String s) {
  final n = double.tryParse(s.trim());
  return (n != null && n.isFinite) ? n : 0;
}

double _sumShares(List<Allocation> a) =>
    a.fold(0.0, (s, x) => s + parseNum(x.shares));

/// Resolve one bucket to money under the active split method.
double moneyOf(Allocation a, SplitMode mode, double total, double sumShares) {
  switch (mode) {
    case SplitMode.percent:
      return total * parseNum(a.pct) / 100;
    case SplitMode.shares:
      return sumShares > 0 ? total * parseNum(a.shares) / sumShares : 0;
    case SplitMode.amount:
      return parseNum(a.amount);
  }
}

/// `"me"` = I paid the bill; otherwise the id of the shared bucket (friend)
/// who paid.
const String kPaidByMe = 'me';

/// Map a saved split to dues (web `splitToDues`).
///
/// - I paid: every Shared bucket with money in it owes me its share.
/// - A friend paid: I owe that friend MY share. What the other friends owe
///   the payer is between them, not mine to record.
/// - Office buckets are a reimbursement claim, not a person's debt.
List<NewSplitDue> splitToDues({
  required List<Allocation> allocations,
  required SplitMode mode,
  required double total,
  required String currency,
  required String paidBy,
  String? note,
  String? sourceId,
}) {
  final sumShares = _sumShares(allocations);
  int paise(Allocation a) => toPaise(moneyOf(a, mode, total, sumShares));
  String name(Allocation a) =>
      a.label.trim().isEmpty ? 'Friend' : a.label.trim();

  if (paidBy == kPaidByMe) {
    return [
      for (final a in allocations)
        if (a.kind == AllocationKind.shared && paise(a) > 0)
          NewSplitDue(
            person: name(a),
            amount: fromPaise(paise(a)),
            currency: currency,
            direction: DueDirection.owedToMe,
            source: DueSource.split,
            note: note,
            sourceId: sourceId,
          ),
    ];
  }
  Allocation? payer;
  for (final a in allocations) {
    if (a.id == paidBy && a.kind == AllocationKind.shared) {
      payer = a;
      break;
    }
  }
  if (payer == null) return const [];
  final mine = allocations
      .where((a) => a.kind == AllocationKind.mine)
      .fold(0, (s, a) => s + paise(a));
  if (mine <= 0) return const [];
  return [
    NewSplitDue(
      person: name(payer),
      amount: fromPaise(mine),
      currency: currency,
      direction: DueDirection.iOwe,
      source: DueSource.split,
      note: note,
      sourceId: sourceId,
    ),
  ];
}

/// Your share of a split, in money (sum of the `mine` buckets, to paise).
double myShareOf(List<Allocation> allocations, SplitMode mode, double total) {
  final sumShares = _sumShares(allocations);
  final p = allocations
      .where((a) => a.kind == AllocationKind.mine)
      .fold(0, (s, a) => s + toPaise(moneyOf(a, mode, total, sumShares)));
  return fromPaise(p);
}

/// Sum of every bucket, to paise.
double allocatedOf(List<Allocation> allocations, SplitMode mode, double total) {
  final sumShares = _sumShares(allocations);
  return fromPaise(
    allocations.fold(
      0,
      (s, a) => s + toPaise(moneyOf(a, mode, total, sumShares)),
    ),
  );
}

/* -------------------------------- Trips -------------------------------- */

class SettleExpense {
  const SettleExpense({
    required this.amount,
    this.currency,
    this.paidBy,
    this.splitWith,
  });

  final double amount;

  /// Defaults to INR — trips are kept in rupees today.
  final String? currency;

  /// Who paid. Defaults to [kMe].
  final String? paidBy;

  /// Companions sharing it; you are always a participant too. Empty = solo.
  final List<String>? splitWith;
}

class Transfer {
  const Transfer({
    required this.from,
    required this.to,
    required this.amount,
    required this.currency,
  });

  final String from;
  final String to;
  final double amount;
  final String currency;

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.from == from &&
      other.to == to &&
      other.amount == amount &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(from, to, amount, currency);

  @override
  String toString() => 'Transfer($from -> $to, $amount $currency)';
}

class _Bal {
  _Bal(this.k, this.v);
  final String k;
  int v;
}

/// Who pays whom to settle a trip (web `settleUp`). Net each person's balance
/// per currency (in paise), then repeatedly match the largest debtor with the
/// largest creditor: at most (people − 1) transfers per currency, and nobody
/// both pays and receives.
List<Transfer> settleUp(List<SettleExpense> expenses) {
  final byCcy = <String, Map<String, int>>{};
  void add(String ccy, String who, int p) {
    final m = byCcy.putIfAbsent(ccy, () => <String, int>{});
    m[who] = (m[who] ?? 0) + p;
  }

  for (final e in expenses) {
    final others = <String>{
      for (final s in e.splitWith ?? const <String>[])
        if (s.trim().isNotEmpty && s.trim() != kMe) s.trim(),
    }.toList();
    final total = toPaise(e.amount);
    if (others.isEmpty || total <= 0) continue;
    final ccy = e.currency ?? 'INR';
    final payer = (e.paidBy?.trim().isNotEmpty ?? false)
        ? e.paidBy!.trim()
        : kMe;
    final people = [kMe, ...others];
    final shares = splitPaise(total, people.length);
    add(ccy, payer, total);
    for (var i = 0; i < people.length; i++) {
      add(ccy, people[i], -shares[i]);
    }
  }

  int order(_Bal a, _Bal b) {
    final d = b.v - a.v;
    return d != 0 ? d : _cmpName(a.k, b.k);
  }

  final out = <Transfer>[];
  final currencies = byCcy.keys.toList()..sort(_cmpName);
  for (final currency in currencies) {
    final balances = byCcy[currency]!;
    final cred = [
      for (final e in balances.entries)
        if (e.value > 0) _Bal(e.key, e.value),
    ];
    final debt = [
      for (final e in balances.entries)
        if (e.value < 0) _Bal(e.key, -e.value),
    ];
    while (cred.isNotEmpty && debt.isNotEmpty) {
      cred.sort(order);
      debt.sort(order);
      final c = cred.first;
      final d = debt.first;
      final p = c.v < d.v ? c.v : d.v;
      out.add(
        Transfer(from: d.k, to: c.k, amount: fromPaise(p), currency: currency),
      );
      c.v -= p;
      d.v -= p;
      if (c.v == 0) cred.removeAt(0);
      if (d.v == 0) debt.removeAt(0);
    }
  }
  return out;
}

/// What a trip expense stores in `paidBy` when you paid (and what a missing
/// value means) — web `TRIP_PAYER_YOU`.
const String kTripPayerYou = 'you';

/// The settle-up name for a stored trip `paidBy`: missing / "you" (any case)
/// → [kMe], else the companion.
String tripPayerName(String? paidBy) {
  final p = (paidBy ?? '').trim();
  return p.isEmpty || p.toLowerCase() == kTripPayerYou ? kMe : p;
}

/// Trip expense items as settle-up input (web `tripSettleExpenses`). Old items
/// carry no `paidBy` and read as paid by you. A companion who paid always
/// shares the bill: added to `splitWith` if the form left them out.
List<SettleExpense> tripSettleExpenses(
  Iterable<({double amount, String? paidBy, List<String>? splitWith})> items,
) {
  return [
    for (final e in items)
      () {
        final paidBy = tripPayerName(e.paidBy);
        final splitWith = e.splitWith ?? const <String>[];
        return SettleExpense(
          amount: e.amount,
          paidBy: paidBy,
          splitWith: paidBy == kMe || splitWith.contains(paidBy)
              ? splitWith
              : [...splitWith, paidBy],
        );
      }(),
  ];
}

/// The transfers that involve you, as dues. Companion-to-companion ones are
/// not yours to record.
List<NewSplitDue> transfersToDues(
  List<Transfer> transfers,
  String tripId,
  String tripName,
) {
  return [
    for (final t in transfers)
      if (t.from == kMe || t.to == kMe)
        NewSplitDue(
          person: t.to == kMe ? t.from : t.to,
          amount: t.amount,
          currency: t.currency,
          direction: t.to == kMe ? DueDirection.owedToMe : DueDirection.iOwe,
          source: DueSource.trip,
          sourceId: tripId,
          note: 'Trip: $tripName',
        ),
  ];
}

/* ------------------------------ Who owes what ------------------------------ */

double remainingOf(SplitDue d) {
  final left = toPaise(d.amount) - toPaise(d.settledAmount);
  return fromPaise(left < 0 ? 0 : left);
}

class PersonBalance {
  const PersonBalance({
    required this.person,
    required this.currency,
    required this.owedToMe,
    required this.iOwe,
    required this.net,
    required this.dues,
  });

  final String person;
  final String currency;
  final double owedToMe;
  final double iOwe;

  /// Positive: they owe you. Negative: you owe them.
  final double net;
  final List<SplitDue> dues;
}

/// Open dues grouped by person (case-insensitive) and currency.
List<PersonBalance> duesByPerson(List<SplitDue> dues) {
  final groups =
      <
        String,
        ({String person, String currency, List<int> sums, List<SplitDue> dues})
      >{};
  for (final d in dues) {
    if (d.settledAt != null) continue;
    final left = toPaise(remainingOf(d));
    if (left <= 0) continue;
    final key = '${d.person.trim().toLowerCase()}|${d.currency}';
    final g = groups.putIfAbsent(
      key,
      () => (
        person: d.person.trim(),
        currency: d.currency,
        sums: [0, 0],
        dues: <SplitDue>[],
      ),
    );
    if (d.direction == DueDirection.owedToMe) {
      g.sums[0] += left;
    } else {
      g.sums[1] += left;
    }
    g.dues.add(d);
  }
  final out = [
    for (final g in groups.values)
      PersonBalance(
        person: g.person,
        currency: g.currency,
        owedToMe: fromPaise(g.sums[0]),
        iOwe: fromPaise(g.sums[1]),
        net: fromPaise(g.sums[0] - g.sums[1]),
        dues: g.dues,
      ),
  ];
  out.sort((a, b) {
    final c = b.net.abs().compareTo(a.net.abs());
    return c != 0 ? c : _cmpName(a.person, b.person);
  });
  return out;
}

/* --------------------------- migration not applied --------------------------- */

const String kSplitDuesMissingMessage =
    'Ask the workspace owner to run the database update '
    '(migration 20261126130000_split_dues.sql).';

/// `split_dues` or `split_due_settle()` does not exist yet: the migration has
/// not been applied.
bool isSplitDuesMissing({String? code, String? message}) {
  if (code == '42P01' || code == 'PGRST205' || code == 'PGRST202') {
    return true;
  }
  final msg = message ?? '';
  return RegExp('split_due', caseSensitive: false).hasMatch(msg) &&
      RegExp(
        'does not exist|schema cache|could not find',
        caseSensitive: false,
      ).hasMatch(msg);
}
