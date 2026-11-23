import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;

/// One card on Home that the person can move or hide.
///
/// The declaration order is the default Home order. The [name]s are the
/// stored ids, the same as the web dashboard's (`src/lib/dashboardCards.ts`)
/// wherever the card exists on both. Never rename one: a stored layout would
/// forget it. A card added later is slotted in at its default place
/// ([HomeLayout.decode]).
enum HomeBlock {
  nudge(
    'Heads-up',
    'A bill due this week, or your top insight',
    Icons.campaign_outlined,
  ),
  netWorth(
    'Net worth',
    'Assets, liabilities and what you saved',
    Icons.account_balance_outlined,
  ),
  monthStats(
    'This month',
    'Income, spent, saved and savings rate',
    Icons.calendar_view_month_outlined,
  ),
  cashFlow(
    'Cash flow',
    'Where money came from and where it went',
    Icons.swap_vert_rounded,
  ),
  health(
    'Financial health',
    'A score from savings, goals and debt',
    Icons.favorite_outline_rounded,
  ),
  spending(
    'Net spending',
    'Spending chart by category',
    Icons.donut_large_rounded,
  ),
  bills('Upcoming bills', 'Your next bill reminders', Icons.event_outlined),
  investments(
    'Investments',
    'Portfolio value and growth',
    Icons.show_chart_rounded,
  ),
  recent(
    'Recent activity',
    'Your latest transactions',
    Icons.receipt_long_outlined,
  ),
  trackers(
    'Trackers',
    'Active trackers, when you have some',
    Icons.track_changes_rounded,
  ),
  insights(
    'Insights',
    'Patterns worth a look, when there are some',
    Icons.lightbulb_outline_rounded,
  );

  const HomeBlock(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  static HomeBlock? fromName(Object? name) {
    for (final b in values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

/// The person's Home: every [HomeBlock] once, in their order, and the ones
/// they turned off. Per device, like the theme (see `HomeLayoutController`).
@immutable
class HomeLayout {
  HomeLayout(List<HomeBlock> order, {Set<HomeBlock> hidden = const {}})
    : order = List.unmodifiable(order),
      hidden = Set.unmodifiable(hidden);

  /// Every card, in the order they ship.
  static final defaults = HomeLayout(HomeBlock.values);

  final List<HomeBlock> order;
  final Set<HomeBlock> hidden;

  /// The cards to draw, top to bottom.
  List<HomeBlock> get visible => [
    for (final b in order)
      if (!hidden.contains(b)) b,
  ];

  bool isShown(HomeBlock b) => !hidden.contains(b);

  bool get isDefault => listEquals(order, HomeBlock.values) && hidden.isEmpty;

  /// Moves the card at [from] so it ends up at [to] (the index it has once
  /// moved, as `ReorderableListView.onReorderItem` reports it).
  HomeLayout move(int from, int to) {
    if (from < 0 || from >= order.length || from == to) return this;
    final next = [...order];
    final b = next.removeAt(from);
    next.insert(to.clamp(0, next.length), b);
    return HomeLayout(next, hidden: hidden);
  }

  HomeLayout withShown(HomeBlock b, bool shown) => HomeLayout(
    order,
    hidden: shown ? ({...hidden}..remove(b)) : {...hidden, b},
  );

  String encode() => jsonEncode({
    'v': 1,
    'order': [for (final b in order) b.name],
    'hidden': [for (final b in order) if (hidden.contains(b)) b.name],
  });

  /// Reads a stored layout. Never throws: anything unreadable is the default.
  /// Unknown ids (a card since removed) and repeats are dropped; a card the
  /// stored layout does not know yet goes back in after the card it follows
  /// by default, so an update never hides a new card at the bottom.
  static HomeLayout decode(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return defaults;
    }
    if (json is! Map) return defaults;
    final storedOrder = json['order'];
    final storedHidden = json['hidden'];
    if (storedOrder is! List) return defaults;

    final order = <HomeBlock>[];
    for (final name in storedOrder) {
      final b = HomeBlock.fromName(name);
      if (b != null && !order.contains(b)) order.add(b);
    }
    for (final b in HomeBlock.values) {
      if (order.contains(b)) continue;
      final before = b.index == 0 ? null : HomeBlock.values[b.index - 1];
      final at = before == null ? -1 : order.indexOf(before);
      order.insert(at + 1, b);
    }

    final hidden = <HomeBlock>{
      if (storedHidden is List)
        for (final name in storedHidden) ?HomeBlock.fromName(name),
    };
    return HomeLayout(order, hidden: hidden);
  }

  @override
  bool operator ==(Object other) =>
      other is HomeLayout &&
      listEquals(other.order, order) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hash(Object.hashAll(order), hidden.length);
}
