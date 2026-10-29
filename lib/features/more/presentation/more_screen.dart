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
import '../../goals/presentation/goals_screen.dart';
import '../../insights/presentation/insights_screen.dart';
import '../../investments/presentation/investments_screen.dart';
import '../../menus/application/menu_providers.dart';
import '../../net_worth/presentation/net_worth_screen.dart';
import '../../recurring/presentation/recurring_screen.dart';
import '../../reminders/presentation/reminders_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../voice/presentation/voice_screen.dart';
import '../../workspace/presentation/workspace_switcher_sheet.dart';

/// "More" — secondary features via progressive disclosure (brief §5).
///
/// Entries whose feature is not in the workspace's effective menus
/// (`get_effective_menus`) render locked rather than hidden: a person who
/// expects a feature should see it is unavailable here, not wonder where it
/// went. No upgrade prompt yet — distinguishing a plan lock from an
/// owner-disabled menu is the billing phase's job (web `menuUpsell`).
///
/// Phone: tapping an entry pushes its route. Tablet (expanded): the list and
/// the chosen feature sit side by side in two panes (M16).
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

    final listBody = ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        const WorkspaceSummaryTile(),
        const Divider(height: 1, indent: 56),
        for (final e in kMoreEntries)
          _MoreTile(
            entry: e,
            selected: twoPane && e.route == selectedRoute,
            onOpen: openEntry,
          ),
      ],
    );

    if (!twoPane) {
      return Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: listBody,
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: TwoPane(
          list: listBody,
          detail: _MorePaneDetail(
            key: ValueKey(selectedRoute),
            route: selectedRoute!,
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: Icon(entry.icon, color: locked ? scheme.onSurfaceVariant : null),
      title: Text(
        entry.label,
        style: locked ? TextStyle(color: scheme.onSurfaceVariant) : null,
      ),
      trailing: _trailing(context, locked),
      onTap: () => onOpen(entry, locked),
    );
  }

  Widget _trailing(BuildContext context, bool locked) {
    if (locked) return const Icon(Icons.lock_outline, size: 18);
    if (entry.phase != null) {
      return Text(
        entry.phase!,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return const Icon(Icons.chevron_right);
  }
}

void showLockedMoreEntry(BuildContext context, MoreEntry entry) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
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
            Icon(
              entry.icon,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${entry.label} isn\'t available',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This feature is turned off for the current workspace. A '
              'workspace owner can change what\'s available on the web app.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
