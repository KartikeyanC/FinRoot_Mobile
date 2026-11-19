import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/components/gradient_fab.dart';
import '../design/tokens/app_breakpoints.dart';
import '../design/tokens/app_palette.dart';
import '../design/tokens/app_radius.dart';
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
/// - compact / medium → a floating dark capsule of round buttons (the main
///   tabs + "More", which opens a sheet; the active tab widens into a white
///   pill with its name) with the gradient "+" for Quick Add in the middle
///   slot. It is part of the dock, not a separate floating button, so
///   a screen's own "+ Tracker"-style button never lands on it.
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
      bottomNavigationBar: _BottomBar(
        onAdd: () => openQuickAdd(context),
        currentIndex: navigationShell.currentIndex,
        onSelected: (i) => destinations[i] == AppDestination.more
            ? showMoreSheet(context)
            : _goBranch(i),
        destinations: destinations,
      ),
    );
  }
}

/// Finds the phone dock in tests.
const kBottomDockKey = ValueKey('bottom-dock');

/// Phones: a floating dark capsule, no shadow. Inactive tabs are graphite circles with
/// an outline icon; the active tab grows into a white pill with its icon and
/// name. The gradient "+" sits in the middle slot.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onAdd,
    required this.currentIndex,
    required this.onSelected,
    required this.destinations,
  });

  final VoidCallback onAdd;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final List<AppDestination> destinations;

  static const double _item = 48;
  static const double _ring = 6;
  static const double _gap = 6;
  static const Color _dock = Color(0xFF0C0C0E);

  @override
  Widget build(BuildContext context) {
    final half = (destinations.length / 2).ceil();
    final slots = <Widget>[
      for (var i = 0; i < half; i++) _tab(i),
      _AddSlot(onAdd: onAdd),
      for (var i = half; i < destinations.length; i++) _tab(i),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          14,
        ),
        child: Center(
          heightFactor: 1,
          // On the narrowest phones (or with large text) the whole dock
          // scales down a touch instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: DecoratedBox(
              key: kBottomDockKey,
              decoration: const ShapeDecoration(
                color: _dock,
                shape: StadiumBorder(),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_ring),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < slots.length; i++) ...[
                      if (i > 0) const SizedBox(width: _gap),
                      slots[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int i) => _DockItem(
    destination: destinations[i],
    selected: i == currentIndex,
    onTap: () => onSelected(i),
  );
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Add a transaction',
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.palette.brandA, context.palette.brandB],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          customBorder: const CircleBorder(),
          child: const SizedBox.square(
            dimension: _BottomBar._item,
            child: Icon(Icons.add_rounded, size: 26, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const _curve = Cubic(0.2, 0.7, 0.2, 1);
  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    // Active: white pill with the icon and name. Inactive: graphite circle,
    // outline icon only.
    final fg = selected ? _BottomBar._dock : Colors.white70;
    final pill = AnimatedContainer(
      duration: _duration,
      curve: _curve,
      height: _BottomBar._item,
      constraints: const BoxConstraints(minWidth: _BottomBar._item),
      padding: EdgeInsets.only(
        left: selected ? 14 : 0,
        right: selected ? 18 : 0,
      ),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: selected ? Colors.white : const Color(0xFF232327),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: fg,
                size: 22,
              ),
              AnimatedSize(
                duration: _duration,
                curve: _curve,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: selected ? pill : Tooltip(message: destination.label, child: pill),
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
          ? GradientExtendedFab(
              tooltip: 'Add a transaction',
              onPressed: () => openQuickAdd(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            )
          : GradientFab(
              tooltip: 'Add a transaction',
              onPressed: () => openQuickAdd(context),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
