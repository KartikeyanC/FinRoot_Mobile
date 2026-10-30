import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../../navigation/destinations.dart';
import '../../../navigation/pane_selection.dart';
import '../../../navigation/two_pane.dart';
import '../../accounts/presentation/accounts_screen.dart';
import '../../bill_scan/presentation/bill_scan_screen.dart';
import '../../budget/presentation/budget_screen.dart';
import '../../calculator/presentation/calculator_screen.dart';
import '../../export/presentation/export_screen.dart';
import '../../goals/presentation/goals_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../investments/presentation/investments_screen.dart';
import '../../menus/application/menu_providers.dart';
import '../../net_worth/presentation/net_worth_screen.dart';
import '../../recurring/presentation/recurring_screen.dart';
import '../../reminders/presentation/reminders_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../voice/presentation/voice_screen.dart';
import '../../web_link/presentation/web_link_screen.dart';
import '../../workspace/presentation/workspace_screen.dart';
import 'workspace_row.dart';

/// "More" — secondary features via progressive disclosure (brief §5).
///
/// Entries whose feature is not in the workspace's effective menus
/// (`get_effective_menus`) render locked rather than hidden: a person who
/// expects a feature should see it is unavailable here, not wonder where it
/// went. No upgrade prompt yet — distinguishing a plan lock from an
/// owner-disabled menu is the billing phase's job (web `menuUpsell`).
///
/// Phone: grouped cards of tiles; tapping one pushes its route. Tablet
/// (expanded): the list and the chosen feature sit side by side in two panes
/// (M16).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twoPane = AppBreakpoints.of(context).showsTwoPane;
    final selectedRoute = twoPane
        ? ref.watch(selectedMoreRouteProvider)
        : null;

    void openEntry(MoreEntry e, bool locked) {
      if (twoPane) {
        ref.read(selectedMoreRouteProvider.notifier).select(e.route);
      } else if (locked) {
        showLockedMoreEntry(context, e);
      } else {
        context.push(e.route);
      }
    }

    final list = _MoreList(
      selectedRoute: selectedRoute,
      onOpen: openEntry,
      showTitle: twoPane,
    );

    if (!twoPane) {
      return AppPage(
        title: 'More',
        subtitle: 'Everything else in your workspace',
        padBody: false,
        body: list,
      );
    }

    return Scaffold(
      backgroundColor: context.palette.page,
      body: SafeArea(
        bottom: false,
        child: TwoPane(
          list: list,
          detail: _MorePaneDetail(
            key: ValueKey(selectedRoute),
            route: selectedRoute!,
          ),
        ),
      ),
    );
  }
}

/// How the entries are grouped into cards, by route.
const _kMoreGroups = <(String, List<String>)>[
  (
    'Money',
    [
      '/accounts',
      '/budget',
      '/goals',
      '/investments',
      '/net-worth',
      '/debts',
      '/trips',
    ],
  ),
  (
    'Plan ahead',
    ['/subscriptions', '/insurance', '/calendar', '/recurring', '/reminders'],
  ),
  (
    'Capture and tools',
    [
      '/bill-scan',
      '/voice',
      '/detected-payments',
      '/insights',
      '/search',
      '/calculator',
      '/import',
      '/export',
    ],
  ),
  ('App', ['/workspace', '/billing', '/backup', '/settings']),
];

class _MoreList extends StatelessWidget {
  const _MoreList({
    required this.selectedRoute,
    required this.onOpen,
    required this.showTitle,
  });

  final String? selectedRoute;
  final void Function(MoreEntry entry, bool locked) onOpen;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final grouped = <String>{for (final g in _kMoreGroups) ...g.$2};
    final others = [
      for (final e in kMoreEntries)
        if (!grouped.contains(e.route)) e,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        if (showTitle)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Semantics(
              header: true,
              child: Text(
                'More',
                style: AppTypography.display.copyWith(
                  color: context.palette.ink,
                ),
              ),
            ),
          ),
        const MoreWorkspaceRow(),
        for (final g in _kMoreGroups) ...[
          SectionTitle(g.$1),
          _MoreGroupCard(
            entries: [
              for (final route in g.$2)
                for (final e in kMoreEntries)
                  if (e.route == route) e,
            ],
            selectedRoute: selectedRoute,
            onOpen: onOpen,
          ),
        ],
        if (others.isNotEmpty) ...[
          const SectionTitle('Other'),
          _MoreGroupCard(
            entries: others,
            selectedRoute: selectedRoute,
            onOpen: onOpen,
          ),
        ],
      ],
    );
  }
}

class _MoreGroupCard extends StatelessWidget {
  const _MoreGroupCard({
    required this.entries,
    required this.selectedRoute,
    required this.onOpen,
  });

  final List<MoreEntry> entries;
  final String? selectedRoute;
  final void Function(MoreEntry entry, bool locked) onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 72,
                endIndent: AppSpacing.lg,
                color: context.palette.line,
              ),
            _MoreTile(
              entry: entries[i],
              selected: entries[i].route == selectedRoute,
              onOpen: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}

/// The embedded feature screen for the tablet More pane. Each real screen is
/// self-contained (its own Scaffold, AppBar, menu-lock handling), so it drops
/// straight in; anything without a screen yet shows a placeholder.
class _MorePaneDetail extends StatelessWidget {
  const _MorePaneDetail({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    switch (route) {
      case '/accounts':
        return const AccountsScreen();
      case '/budget':
        return const BudgetScreen();
      case '/goals':
        return const GoalsScreen();
      case '/investments':
        return const InvestmentsScreen();
      case '/net-worth':
        return const NetWorthScreen();
      case '/recurring':
        return const RecurringScreen();
      case '/reminders':
        return const RemindersScreen();
      case '/bill-scan':
        return const BillScanScreen();
      case '/voice':
        return const VoiceScreen();
      case '/insights':
        return const InsightsScreen();
      case '/trips':
        return const TripsScreen();
      case '/calculator':
        return const CalculatorScreen();
      case '/import':
        return const ImportScreen();
      case '/export':
        return const ExportScreen();
      case '/workspace':
        return const WorkspaceScreen();
      case '/billing':
        return const BillingScreen();
      case '/settings':
        return const SettingsScreen();
    }
    final entry = kMoreEntries.firstWhere(
      (e) => e.route == route,
      orElse: () => kMoreEntries.first,
    );
    return PlaceholderScreen(
      title: entry.label,
      milestone: entry.phase ?? 'a later phase',
      icon: entry.icon,
    );
  }
}

class _MoreTile extends ConsumerWidget {
  const _MoreTile({
    required this.entry,
    required this.selected,
    required this.onOpen,
  });

  final MoreEntry entry;
  final bool selected;
  final void Function(MoreEntry entry, bool locked) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = entry.menu == null
        ? MenuStatus.available
        : ref.watch(menuStatusProvider(entry.menu!));
    final locked = status == MenuStatus.locked;
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.tint : Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(entry, locked),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget + 8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconTile(
                    icon: entry.icon,
                    size: 40,
                    tint: locked ? palette.subtle : null,
                    color: locked ? palette.faint : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      entry.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 15,
                        color: locked ? palette.muted : palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (locked)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: palette.faint,
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: palette.faint),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showLockedMoreEntry(BuildContext context, MoreEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: entry.icon,
                size: 48,
                tint: palette.subtle,
                color: palette.muted,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "${entry.label} isn't available",
                style: AppTypography.title.copyWith(color: palette.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This feature is turned off for the current workspace. A '
                "workspace owner can change what's available on the web app.",
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
