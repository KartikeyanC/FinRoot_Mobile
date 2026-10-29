import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/components/gradient_fab.dart';
import '../design/tokens/app_breakpoints.dart';
import '../design/tokens/app_palette.dart';
import '../design/tokens/app_spacing.dart';
import '../features/payment_capture/presentation/payment_popup_opener.dart';
import '../features/price_alerts/presentation/price_alert_watcher.dart';
import '../features/sync/presentation/live_data_refresher.dart';
import '../features/sync/presentation/sync_status_widgets.dart';
import '../features/workspace/application/workspace_providers.dart';
import '../features/workspace/domain/membership.dart';
import '../features/workspace/presentation/workspace_switcher_sheet.dart';
import 'destinations.dart';
import 'more_sheet.dart';
import 'quick_add_entry.dart';

/// The adaptive app shell (M1 audit §11, §14, §15).
///
/// - compact / medium → NineFlow's phone layout: a bottom tab bar (the main
///   tabs + "More", which opens a sheet) and a floating gradient "+" for
///   Quick Add, bottom right.
/// - expanded (tablet) → `NavigationRail` + Quick Add as the rail's leading
///   action; content gets the rest of the width for future split views.
///
/// One widget, one codebase — the layout switches on width, never on a build
/// flavor.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) => LiveDataRefresher(
    child: PriceAlertWatcher(
      child: PaymentPopupOpener(child: _layout(context)),
    ),
  );

  Widget _layout(BuildContext context) {
    final size = AppBreakpoints.of(context);
    const destinations = AppDestination.values;

    if (size.showsRail) {
      final railExtended = AppBreakpoints.railExtendedAt(
        MediaQuery.sizeOf(context).width,
      );
      return Scaffold(
        body: Row(
          children: [
            _Rail(
              currentIndex: navigationShell.currentIndex,
              onSelected: _goBranch,
              destinations: destinations,
              extended: railExtended,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  const SyncStatusBanner(),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          const SyncStatusBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: GradientFab(
        tooltip: 'Add a transaction',
        onPressed: () => openQuickAdd(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: (i) => destinations[i] == AppDestination.more
            ? showMoreSheet(context)
            : _goBranch(i),
        destinations: destinations,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Card-coloured bar with a 1px top line; one equal slot per destination
    // (at most 4 tabs + More, per NineFlow).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(top: BorderSide(color: palette.line)),
      ),
      child: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        elevation: 0,
        color: palette.card,
        surfaceTintColor: Colors.transparent,
        child: Row(
          children: [
            for (var i = 0; i < destinations.length; i++)
              Expanded(
                child: _BottomItem(
                  destination: destinations[i],
                  selected: i == currentIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Active: icon in a 28x40 accent-tint pill, label in accent text.
    // Inactive: faint. Labels are 10sp semibold (micro).
    final color = selected ? palette.accentText : palette.faint;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: const Cubic(0.2, 0.7, 0.2, 1),
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? palette.tint : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
    required this.extended,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<AppDestination> destinations;
  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leading = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: extended
          ? FloatingActionButton.extended(
              heroTag: 'quick-add-rail',
              elevation: 0,
              tooltip: 'Add a transaction',
              onPressed: () => openQuickAdd(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : FloatingActionButton(
              heroTag: 'quick-add-rail',
              elevation: 0,
              tooltip: 'Add a transaction',
              onPressed: () => openQuickAdd(context),
              child: const Icon(Icons.add_rounded),
            ),
    );

    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      extended: extended,
      labelType: extended ? null : NavigationRailLabelType.all,
      leading: leading,
      // NavigationRail scrolls its own body, so the footer trails the
      // destinations rather than pinning to the very bottom — fine at every
      // supported tablet height.
      trailing: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: _RailFooter(extended: extended),
      ),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
      ],
    );
  }
}

/// Workspace switcher + Settings, pinned below the rail's destinations (M1
/// audit §15 — "the workspace switcher and profile move to a rail footer").
class _RailFooter extends ConsumerWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider);
    final usableCount =
        (ref.watch(membershipsProvider).value ?? const <Membership>[])
            .where((m) => m.isUsable)
            .length;
    final canSwitch = usableCount > 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(
            height: 1,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (extended && membership != null)
            _WorkspaceChip(
              name: membership.name,
              onTap: canSwitch ? () => showWorkspaceSwitcher(context) : null,
            )
          else
            IconButton(
              tooltip: canSwitch
                  ? 'Switch workspace'
                  : (membership?.name ?? 'Workspace'),
              onPressed: canSwitch
                  ? () => showWorkspaceSwitcher(context)
                  : null,
              icon: const Icon(Icons.workspaces_outline),
            ),
          const SizedBox(height: AppSpacing.xs),
          if (extended)
            TextButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Settings'),
            )
          else
            IconButton(
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  const _WorkspaceChip({required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.secondaryContainer,
                child: Text(
                  name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.unfold_more,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
