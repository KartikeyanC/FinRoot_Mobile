import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/design.dart';
import '../features/menus/application/menu_providers.dart';
import '../features/more/presentation/more_screen.dart';
import 'destinations.dart';

/// The phone "More" tab (NineFlow): a bottom sheet with a grid of 80dp tiles
/// (16dp radius) for every secondary feature. Menu-locked entries stay
/// visible with a lock and explain themselves instead of opening.
Future<void> showMoreSheet(BuildContext context) {
  // Routes are pushed from the shell's context once the sheet has closed.
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _MoreSheet(
      onOpen: (entry, locked) {
        Navigator.of(sheetContext).pop();
        if (locked) {
          showLockedMoreEntry(context, entry);
        } else {
          router.push(entry.route);
        }
      },
    ),
  );
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.onOpen});

  final void Function(MoreEntry entry, bool locked) onOpen;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('More', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 96).floor().clamp(
                    3,
                    6,
                  );
                  return GridView.builder(
                    shrinkWrap: true,
                    itemCount: kMoreEntries.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 80,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                    itemBuilder: (_, i) =>
                        _MoreTile(entry: kMoreEntries[i], onOpen: onOpen),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends ConsumerWidget {
  const _MoreTile({required this.entry, required this.onOpen});

  final MoreEntry entry;
  final void Function(MoreEntry entry, bool locked) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = entry.menu == null
        ? MenuStatus.available
        : ref.watch(menuStatusProvider(entry.menu!));
    final locked = status == MenuStatus.locked;
    final palette = context.palette;
    final color = locked ? palette.faint : palette.ink;

    return Semantics(
      button: true,
      label: locked ? '${entry.label}, unavailable' : entry.label,
      excludeSemantics: true,
      child: Material(
        color: palette.subtle,
        borderRadius: AppRadius.tile,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpen(entry, locked),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  locked ? Icons.lock_outline : entry.icon,
                  size: 22,
                  color: locked ? palette.faint : palette.accentText,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
