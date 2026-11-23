import 'package:flutter/material.dart';

/// Income streams (`income_streams` table) — the phone half of the web's
/// Income page (`src/pages/Income.tsx`, `src/hooks/useIncomeStreams.ts`,
/// `src/lib/incomeSeed.ts`): the same columns, currencies, default exchange
/// rates, icon names, visibility and order, so a stream made on either app
/// shows on the other.

/// Web `DEFAULT_FX`: rupees per unit.
const kIncomeFx = {'INR': 1.0, 'USD': 83.5, 'EUR': 90.0};

const kIncomeCurrencySymbols = {'INR': '₹', 'USD': r'$', 'EUR': '€'};

/// Web `IncomeFrequency`, with how the phone labels it.
const kIncomeFrequencies = {
  'monthly': 'Monthly',
  'weekly': 'Weekly',
  'one-time': 'One-time',
};

/// Web `ACTIVE_INCOME`; every other income category is passive.
const kActiveIncomeCategories = ['Salary', 'Freelance', 'Business'];
const kPassiveIncomeCategories = [
  'Investment',
  'Rental',
  'Dividend',
  'Interest',
  'Other',
];

/// Web `ICON_MAP` keys (lucide names, stored as-is) → the Material icon the
/// phone draws for each. Unknown names fall back to coins, as on the web.
const kIncomeIcons = <String, IconData>{
  'Briefcase': Icons.work_outline_rounded,
  'Home': Icons.home_outlined,
  'TrendingUp': Icons.trending_up_rounded,
  'GraduationCap': Icons.school_outlined,
  'Youtube': Icons.smart_display_outlined,
  'Megaphone': Icons.campaign_outlined,
  'School': Icons.account_balance_outlined,
  'Mic': Icons.mic_none_rounded,
  'Scissors': Icons.content_cut_rounded,
  'Palette': Icons.palette_outlined,
  'PiggyBank': Icons.savings_outlined,
  'Building2': Icons.business_outlined,
  'Gift': Icons.card_giftcard_outlined,
  'Receipt': Icons.receipt_long_outlined,
  'ArrowLeftRight': Icons.swap_horiz_rounded,
  'Coins': Icons.paid_outlined,
};

IconData incomeIcon(String name) => kIncomeIcons[name] ?? Icons.paid_outlined;

double _num(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

class IncomeStream {
  const IncomeStream({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.amount,
    required this.currency,
    required this.rate,
    required this.visible,
    required this.order,
    this.frequency = 'monthly',
    this.notes,
  });

  factory IncomeStream.fromRow(Map<String, dynamic> r) {
    final currency = (r['currency'] as String?) ?? 'INR';
    final rate = _num(r['exchange_rate_to_inr']);
    final freq = r['frequency'] as String?;
    return IncomeStream(
      id: r['id'] as String,
      name: (r['name'] as String?) ?? 'Income',
      type: r['type'] == 'active' ? 'active' : 'passive',
      icon: (r['icon'] as String?) ?? 'Coins',
      amount: _num(r['amount']),
      currency: currency,
      rate: rate > 0 ? rate : (kIncomeFx[currency] ?? 1),
      visible: r['is_visible'] != false,
      order: (r['display_order'] as num?)?.toInt() ?? 0,
      frequency: kIncomeFrequencies.containsKey(freq) ? freq! : 'monthly',
      notes: r['notes'] as String?,
    );
  }

  final String id;
  final String name;

  /// `active` (salary, work) or `passive` (rent, dividends…).
  final String type;
  final String icon;
  final double amount;
  final String currency;

  /// Rupees per unit of [currency].
  final double rate;
  final bool visible;
  final int order;
  final String frequency;
  final String? notes;

  bool get isActive => type == 'active';
  bool get isForeign => currency != 'INR';

  /// The amount in rupees, per payment.
  double get inr => amount * rate;

  /// What it brings in a month, in rupees: weekly × 52 ÷ 12; a one-time
  /// payment adds nothing to a month.
  double get monthlyInr => switch (frequency) {
    'weekly' => inr * 52 / 12,
    'one-time' => 0,
    _ => inr,
  };

  String get frequencyLabel => kIncomeFrequencies[frequency] ?? 'Monthly';
}

/// What the person typed for a stream.
class IncomeStreamDraft {
  const IncomeStreamDraft({
    required this.name,
    required this.type,
    required this.amount,
    required this.currency,
    required this.rate,
    this.frequency = 'monthly',
    this.icon = 'Coins',
    this.notes = '',
  });

  final String name;
  final String type;
  final double amount;
  final String currency;
  final double rate;
  final String frequency;
  final String icon;
  final String notes;

  /// The columns the web's `streamToRow` writes for these fields.
  Map<String, dynamic> toRow() => {
    'name': name.trim().isEmpty ? 'Custom' : name.trim(),
    'type': type,
    'icon': icon,
    'amount': amount,
    'currency': currency,
    'exchange_rate_to_inr': rate > 0 ? rate : (kIncomeFx[currency] ?? 1),
    'frequency': frequency,
    'notes': notes.trim().isEmpty ? null : notes.trim(),
  };
}

/// The figures at the top of the Income page, over the shown streams.
class IncomeSummary {
  const IncomeSummary({
    required this.monthly,
    required this.active,
    required this.passive,
    required this.foreign,
    required this.oneTime,
    required this.count,
  });

  factory IncomeSummary.of(Iterable<IncomeStream> streams) {
    var monthly = 0.0, active = 0.0, passive = 0.0, oneTime = 0.0;
    var foreign = 0, count = 0;
    for (final s in streams) {
      if (!s.visible) continue;
      count++;
      monthly += s.monthlyInr;
      if (s.isActive) {
        active += s.monthlyInr;
      } else {
        passive += s.monthlyInr;
      }
      if (s.isForeign) foreign++;
      if (s.frequency == 'one-time') oneTime += s.inr;
    }
    return IncomeSummary(
      monthly: monthly,
      active: active,
      passive: passive,
      foreign: foreign,
      oneTime: oneTime,
      count: count,
    );
  }

  final double monthly;
  final double active;
  final double passive;

  /// Streams paid in a currency other than rupees.
  final int foreign;

  /// One-time payments, in rupees (not part of [monthly]).
  final double oneTime;
  final int count;
}

/// The shown streams in display order.
List<IncomeStream> shownInOrder(Iterable<IncomeStream> all) =>
    all.where((s) => s.visible).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

/// Web `reorder` / `move`: [shown] with the stream at [from] moved to [to],
/// numbered 1, 2, 3… (`display_order`). Only rows whose number changes are
/// returned, so a move writes as little as possible.
Map<String, int> reorderedPositions(
  List<IncomeStream> shown,
  int from,
  int to,
) {
  if (from < 0 || from >= shown.length || to < 0 || to >= shown.length) {
    return const {};
  }
  final list = [...shown];
  final moved = list.removeAt(from);
  list.insert(to, moved);
  return {
    for (var i = 0; i < list.length; i++)
      if (list[i].order != i + 1) list[i].id: i + 1,
  };
}

abstract final class IncomeValidators {
  static String? amount(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter the amount';
    if (n > 1e12) return 'That amount is too large';
    return null;
  }

  static String? rate(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '').trim());
    if (n == null || !n.isFinite || n <= 0) return 'Enter the rate in rupees';
    if (n > 1e6) return 'That rate is too large';
    return null;
  }

  static String? name(String? v) =>
      (v?.trim().length ?? 0) > 60 ? 'That name is too long' : null;
}
