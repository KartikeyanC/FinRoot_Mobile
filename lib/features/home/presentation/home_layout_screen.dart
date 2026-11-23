import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../application/home_layout_controller.dart';
import '../domain/home_layout.dart';

/// "Customize home": every Home card in the person's order. Drag a card by its
/// handle (or long-press it) to move it; the switch shows or hides it. Each
/// change saves on this phone at once, so there is no Save button.
class HomeLayoutScreen extends ConsumerWidget {
  const HomeLayoutScreen({super.key});

  static const route = '/home-layout';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    final controller = ref.read(homeLayoutProvider.notifier);

    return AppPage(
      title: 'Customize home',
      subtitle: 'Drag cards into the order you want. Turn off what you '
          "don't need.",
      padBody: false,
      actions: [
        RoundIconButton(
          icon: Icons.restart_alt_rounded,
          tooltip: 'Reset to default',
          onPressed: layout.isDefault ? null : () => _reset(context, ref),
        ),
      ],
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        buildDefaultDragHandles: false,
        itemCount: layout.order.length,
        onReorderStart: (_) => HapticFeedback.selectionClick(),
        onReorderItem: controller.move,
        proxyDecorator: _lifted,
        footer: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(
            'Saved on this phone. Your other devices keep their own layout.',
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: context.palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        itemBuilder: (context, i) {
          final block = layout.order[i];
          final menu = _menuOf(block);
          return Padding(
            key: ValueKey(block),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _BlockRow(
              block: block,
              index: i,
              shown: layout.isShown(block),
              locked:
                  menu != null &&
                  ref.watch(menuStatusProvider(menu)) == MenuStatus.locked,
              onShown: (v) => controller.setShown(block, v),
            ),
          );
        },
      ),
    );
  }

  void _reset(BuildContext context, WidgetRef ref) {
    final before = ref.read(homeLayoutProvider);
    ref.read(homeLayoutProvider.notifier).reset();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Home is back to the default layout'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                ref.read(homeLayoutProvider.notifier).restore(before),
          ),
        ),
      );
  }

  /// The plan menu a card depends on, if any.
  static FeatureMenu? _menuOf(HomeBlock b) => switch (b) {
    HomeBlock.netWorth => FeatureMenu.netWorth,
    HomeBlock.spending => FeatureMenu.expenses,
    HomeBlock.bills => FeatureMenu.reminders,
    HomeBlock.investments => FeatureMenu.investments,
    HomeBlock.trackers => FeatureMenu.trackers,
    _ => null,
  };

  /// The card being dragged: lifted a touch and ringed in the accent, without
  /// a drop shadow (the app's surfaces are flat).
  static Widget _lifted(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOut.transform(animation.value);
        return Transform.scale(
          scale: 1 + 0.03 * t,
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: AppRadius.card,
                border: Border.all(
                  color: context.palette.accent.withValues(alpha: t),
                  width: 1.5,
                ),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _BlockRow extends StatelessWidget {
  const _BlockRow({
    required this.block,
    required this.index,
    required this.shown,
    required this.locked,
    required this.onShown,
  });

  final HomeBlock block;
  final int index;
  final bool shown;
  final bool locked;
  final ValueChanged<bool> onShown;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Long-press anywhere on the row drags it too.
    return ReorderableDelayedDragStartListener(
      index: index,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            // The handle starts a drag at once. 48dp to hit.
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Drag to move',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: palette.faint,
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: shown ? 1 : 0.5,
              child: IconTile(icon: block.icon, size: 40),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            block.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyStrong.copyWith(
                              color: shown ? palette.ink : palette.muted,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locked ? 'Not on your plan' : block.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.label.copyWith(
                              color: palette.muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Switch(value: shown, onChanged: onShown),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
