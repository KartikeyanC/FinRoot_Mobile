import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';

/// A manual net-worth line item. The web (`src/lib/netWorthStore.ts`) computes
/// net worth purely from these — assets minus liabilities — it does **not**
/// auto-compose from accounts or investments.
class NetWorthEntry {
  const NetWorthEntry({
    required this.id,
    required this.kind,
    required this.group,
    required this.name,
    required this.amount,
    this.createdAt,
  });

  final String id;
  final String kind; // asset | liability
  final String group;
  final String name;
  final Money amount;
  final DateTime? createdAt;

  bool get isAsset => kind == 'asset';

  factory NetWorthEntry.fromRow(Map<String, dynamic> r) => NetWorthEntry(
    id: r['id'] as String,
    kind: (r['kind'] as String?) ?? 'asset',
    group: (r['grp'] as String?) ?? 'other_asset',
    name: (r['name'] as String?) ?? '',
    amount: Money(Decimal.parse((r['amount'] ?? 0).toString())),
    createdAt: DateTime.tryParse((r['created_at'] as String?) ?? ''),
  );
}

class NetWorthDraft {
  const NetWorthDraft({
    required this.kind,
    required this.group,
    required this.name,
    required this.amount,
  });

  final String kind;
  final String group;
  final String name;
  final Money amount;
}

/// A point on the net-worth trend, from `net_worth_snapshots`.
class NetWorthPoint {
  const NetWorthPoint({
    required this.capturedOn,
    required this.assets,
    required this.liabilities,
  });

  final DateTime capturedOn;
  final Money assets;
  final Money liabilities;

  Money get netWorth => assets - liabilities;

  factory NetWorthPoint.fromRow(Map<String, dynamic> r) => NetWorthPoint(
    capturedOn: DateTime.parse(r['captured_on'] as String),
    assets: Money(Decimal.parse((r['assets'] ?? 0).toString())),
    liabilities: Money(Decimal.parse((r['liabilities'] ?? 0).toString())),
  );
}

const List<({String id, String label})> kAssetGroups = [
  (id: 'liquid', label: 'Liquid Cash'),
  (id: 'bank', label: 'Bank Accounts'),
  (id: 'mutual_funds', label: 'Mutual Funds'),
  (id: 'stocks', label: 'Stock Brokerages'),
  (id: 'other_asset', label: 'Other Assets'),
];

const List<({String id, String label})> kLiabilityGroups = [
  (id: 'credit_card', label: 'Credit Card Outstanding'),
  (id: 'car_loan', label: 'Car Loans'),
  (id: 'home_loan', label: 'Home EMI'),
  (id: 'personal_loan', label: 'Personal Loans'),
  (id: 'other_liability', label: 'Other Liabilities'),
];

String groupLabel(String id) {
  for (final g in [...kAssetGroups, ...kLiabilityGroups]) {
    if (g.id == id) return g.label;
  }
  return id;
}

class NetWorthTotals {
  const NetWorthTotals({required this.assets, required this.liabilities});

  final Money assets;
  final Money liabilities;

  Money get netWorth => assets - liabilities;

  factory NetWorthTotals.of(Iterable<NetWorthEntry> entries) {
    var assets = Money.zero();
    var liabilities = Money.zero();
    for (final e in entries) {
      if (e.isAsset) {
        assets = assets + Money(e.amount.amount);
      } else {
        liabilities = liabilities + Money(e.amount.amount);
      }
    }
    return NetWorthTotals(assets: assets, liabilities: liabilities);
  }
}

abstract final class NetWorthValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Name this item';
    if (t.length > 100) return 'That name is too long';
    return null;
  }

  static String? amount(String? v) {
    final m = Money.tryParse(v ?? '');
    if (m == null) return 'Enter an amount';
    if (!m.isPositive) return 'Enter an amount above zero';
    if (m > Money.parse('999999999999.99')) return 'That amount is too large';
    return null;
  }
}
