import 'package:flutter/material.dart';

/// Swipe the content right-to-left for the next filter tab and left-to-right
/// for the previous one — the chip row above stays the visible control, this
/// just adds the gesture (Trackers status, Transactions type).
///
/// Only a deliberate horizontal fling counts, so vertical list scrolling and
/// pull-to-refresh are unaffected. The content slides in from the side the
/// user swiped towards, so the change reads as "moved to the next tab".
class SwipeTabs extends StatefulWidget {
  const SwipeTabs({
    super.key,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.child,
  });

  /// The selected tab, 0-based.
  final int index;
  final int count;
  final ValueChanged<int> onChanged;
  final Widget child;

  /// Fling speed (logical px/s) below which a horizontal drag is ignored.
  static const minFlingVelocity = 300.0;

  @override
  State<SwipeTabs> createState() => _SwipeTabsState();
}

class _SwipeTabsState extends State<SwipeTabs> {
  // +1 when moving to a later tab (content enters from the right), -1 earlier.
  int _direction = 1;

  @override
  void didUpdateWidget(SwipeTabs old) {
    super.didUpdateWidget(old);
    // A chip tap changes the index too; slide the matching way.
    if (widget.index != old.index) {
      _direction = widget.index > old.index ? 1 : -1;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v.abs() < SwipeTabs.minFlingVelocity) return;
    final next = widget.index + (v < 0 ? 1 : -1);
    if (next < 0 || next >= widget.count) return;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _onDragEnd,
      child: AnimatedSwitcher(
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final entering = child.key == ValueKey(widget.index);
          final dx = 0.15 * _direction * (entering ? 1 : -1);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(dx, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        layoutBuilder: (current, previous) =>
            Stack(children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(widget.index), child: widget.child),
      ),
    );
  }
}

/// Keeps a chip on screen when it becomes selected — a swipe can select a
/// chip that is scrolled out of view in its horizontal row.
class RevealWhenSelected extends StatefulWidget {
  const RevealWhenSelected({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  State<RevealWhenSelected> createState() => _RevealWhenSelectedState();
}

class _RevealWhenSelectedState extends State<RevealWhenSelected> {
  @override
  void didUpdateWidget(RevealWhenSelected old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
