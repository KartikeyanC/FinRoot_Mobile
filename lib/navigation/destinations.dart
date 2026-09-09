import 'package:flutter/material.dart';

import '../domain/constants.dart';

/// A primary navigation target. The order here is the order in the bottom bar
/// / rail. Quick Add is deliberately NOT in this list — it is an action button,
/// not a destination (brief §5, §7).
enum AppDestination {
  home(
    path: '/',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  transactions(
    path: '/transactions',
    label: 'Transactions',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
  trackers(
    path: '/trackers',
    label: 'Trackers',
    icon: Icons.donut_large_outlined,
    selectedIcon: Icons.donut_large_rounded,
    menu: FeatureMenu.trackers,
  ),
  more(
    path: '/more',
    label: 'More',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  );

  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.menu,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// If set, this destination is only shown when the workspace's effective
  /// menus include it (M3 wires the real check; today everything shows).
  final FeatureMenu? menu;

  static AppDestination byIndex(int i) => AppDestination.values[i];
}

/// Secondary features that live under "More" (brief §5). Menu-gated where the
/// web equivalent is.
class MoreEntry {
  const MoreEntry(this.label, this.icon, this.route, {this.menu, this.phase});
  final String label;
  final IconData icon;
  final String route;
  final FeatureMenu? menu;

  /// Which milestone delivers the real screen. Null once shipped.
  final String? phase;
}

const kMoreEntries = <MoreEntry>[
  MoreEntry(
    'Accounts',
    Icons.account_balance_wallet_outlined,
    '/accounts',
  ),
  MoreEntry(
    'Budget',
    Icons.pie_chart_outline,
    '/budget',
    menu: FeatureMenu.budget,
  ),
  MoreEntry(
    'Goals',
    Icons.flag_outlined,
    '/goals',
    menu: FeatureMenu.goals,
  ),
  MoreEntry(
    'Investments',
    Icons.trending_up,
    '/investments',
    menu: FeatureMenu.investments,
  ),
  MoreEntry(
    'Net Worth',
    Icons.balance_outlined,
    '/net-worth',
    menu: FeatureMenu.netWorth,
  ),
  MoreEntry(
    'Recurring',
    Icons.event_repeat_outlined,
    '/recurring',
  ),
  MoreEntry(
    'Reminders',
    Icons.notifications_none,
    '/reminders',
    menu: FeatureMenu.reminders,
  ),
  MoreEntry(
    'Bill Scan',
    Icons.document_scanner_outlined,
    '/bill-scan',
    menu: FeatureMenu.billScan,
  ),
  MoreEntry('Voice', Icons.mic_none, '/voice'),
  MoreEntry('Insights', Icons.insights_outlined, '/insights'),
  MoreEntry('Search', Icons.search, '/search', phase: 'M8'),
  MoreEntry('Settings', Icons.settings_outlined, '/settings', phase: 'M3'),
];
