import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';

/// One investment holding. The web keeps class-specific inputs in a free-form
/// `fields` map and computed values in `derived` (`src/lib/investmentsStore.ts`).
/// Mobile writes a **normalized** record — `fields = {name, invested, current,
/// _mobile: '1'}` — and [invested] / [current] read that directly; a record
/// written by the web is read through the ported per-asset logic instead
/// (`investment_getters_parity_test`).
class InvestmentRecord {
  const InvestmentRecord({
    required this.id,
    required this.asset,
    required this.currency,
    required this.fields,
    required this.derived,
    this.goal,
    this.savedAt,
  });

  final String id;
  final String asset;
  final String currency;
  final Map<String, dynamic> fields;
  final Map<String, dynamic> derived;
  final String? goal;
  final DateTime? savedAt;

  bool get isMobileRecord => fields['_mobile'] == '1';

  String get name {
    final f = fields;
    final candidate = (f['name'] ??
            f['ticker'] ??
            f['scheme'] ??
            f['bond_name'] ??
            f['property'] ??
            f['coin'])
        as String?;
    if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    return kAssetLabels[asset] ?? asset;
  }

  Money get invested => Money(_dec(_investedRaw()), currency);
  Money get current => Money(_dec(_currentRaw()), currency);

  /// Gain (may be negative). `current - invested`.
  Money get gain => current - invested;

  double _investedRaw() {
    if (isMobileRecord) return _num(fields['invested']);
    final f = fields;
    final d = derived;
    return switch (asset) {
      'stocks' => _num(d['total']),
      'mutual_funds' => _num(f['invested']),
      'fd' => _num(f['deposit']),
      'rd' => _num(d['principal']),
      'pf' => _num(d['contribTotal']) != 0
          ? _num(d['contribTotal'])
          : _num(f['balance']),
      'gold' => _num(d['invested']),
      'real_estate' => _num(d['totalCost']),
      'crypto' => _num(d['invested']),
      'bonds' => _num(f['invested']),
      _ => 0,
    };
  }

  double _currentRaw() {
    if (isMobileRecord) return _num(fields['current']);
    final f = fields;
    final d = derived;
    double or(double a, double b) => a != 0 ? a : b;
    return switch (asset) {
      'stocks' => or(_num(f['current']), _num(d['total'])),
      'mutual_funds' => or(_num(d['currentValue']), _num(f['invested'])),
      'fd' => or(_num(d['maturity']), _num(f['deposit'])),
      'rd' => or(_num(d['maturity']), _num(d['principal'])),
      'pf' => or(_num(d['total']), _num(f['balance'])),
      'gold' => or(_num(d['currentValue']), _num(d['invested'])),
      'real_estate' => or(_num(d['current']), _num(d['totalCost'])),
      'crypto' => or(_num(f['current']), _num(d['invested'])),
      'bonds' => or(_num(d['current']), _num(f['invested'])),
      _ => 0,
    };
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Decimal _dec(double v) => Decimal.parse(v.toStringAsFixed(2));
}

/// Asset classes (web `AssetType`). Order = picker order.
const List<String> kAssetTypes = [
  'stocks',
  'mutual_funds',
  'bonds',
  'fd',
  'rd',
  'pf',
  'gold',
  'real_estate',
  'crypto',
];

const Map<String, String> kAssetLabels = {
  'stocks': 'Stocks',
  'mutual_funds': 'Mutual Funds',
  'bonds': 'Bonds',
  'fd': 'Fixed Deposit',
  'rd': 'Recurring Deposit',
  'pf': 'Provident Fund',
  'gold': 'Gold',
  'real_estate': 'Real Estate',
  'crypto': 'Crypto',
};

String assetLabel(String asset) => kAssetLabels[asset] ?? asset;

IconData assetIcon(String asset) => switch (asset) {
  'stocks' => Icons.show_chart,
  'mutual_funds' => Icons.pie_chart_outline,
  'bonds' => Icons.receipt_long_outlined,
  'fd' => Icons.lock_clock_outlined,
  'rd' => Icons.event_repeat_outlined,
  'pf' => Icons.savings_outlined,
  'gold' => Icons.diamond_outlined,
  'real_estate' => Icons.home_work_outlined,
  'crypto' => Icons.currency_bitcoin,
  _ => Icons.account_balance_outlined,
};

/// Goal links the web offers.
const List<String> kInvestmentGoals = [
  'Retirement',
  'House Fund',
  "Kid's Education",
  'Emergency Stack',
];

class InvestmentDraft {
  const InvestmentDraft({
    required this.asset,
    required this.name,
    required this.invested,
    required this.current,
    this.goal,
    this.currency = 'INR',
  });

  final String asset;
  final String name;
  final Money invested;
  final Money current;
  final String? goal;
  final String currency;
}

abstract final class InvestmentValidators {
  static String? name(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return 'Name this holding';
    if (t.length > 100) return 'That name is too long';
    return null;
  }

  static String? amount(String? v, {required String label}) {
    final m = Money.tryParse(v ?? '');
    if (m == null) return 'Enter $label';
    if (m.isNegative) return '$label cannot be negative';
    if (m > Money.parse('999999999999.99')) return 'That amount is too large';
    return null;
  }
}
