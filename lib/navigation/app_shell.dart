import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens/app_breakpoints.dart';
import '../design/tokens/app_spacing.dart';
import 'destinations.dart';
import 'quick_add_entry.dart';

/// The adaptive app shell (M1 audit §11, §14, §15).
///
/// - compact / medium → bottom `NavigationBar` + a centered Quick Add button.
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
  Widget build(BuildContext context) {
    final size = AppBreakpoints.of(context);
    const destinations = AppDestination.values;

    if (size.showsRail) {
      return Scaffold(
        body: Row(
          children: [
            _Rail(
              currentIndex: navigationShell.currentIndex,
              onSelected: _goBranch,
              destinations: destinations,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        heroTag: 'quick-add-fab',
        tooltip: 'Add a transaction',
        onPressed: () => openQuickAdd(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelected: _goBranch,
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
    final scheme = Theme.of(context).colorScheme;
    // 4 destinations split 2 + 2 around the docked Quick Add button.
    final left = destinations.take(2).toList();
    final right = destinations.skip(2).toList();

    Widget item(AppDestination d) => _BottomItem(
      destination: d,
      selected: destinations.indexOf(d) == currentIndex,
      onTap: () => onSelected(destinations.indexOf(d)),
    );

    return BottomAppBar(
      height: 68,
      padding: EdgeInsets.zero,
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          ...left.map((d) => Expanded(child: item(d))),
          const SizedBox(width: 64), // notch gap
          ...right.map((d) => Expanded(child: item(d))),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
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
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<AppDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: FloatingActionButton(
          heroTag: 'quick-add-rail',
          elevation: 0,
          tooltip: 'Add a transaction',
          onPressed: () => openQuickAdd(context),
          child: const Icon(Icons.add_rounded),
        ),
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
