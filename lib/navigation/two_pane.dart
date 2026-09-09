import 'package:flutter/material.dart';

import '../design/tokens/app_breakpoints.dart';
import '../design/tokens/app_spacing.dart';

/// A list/detail split for the expanded (tablet) breakpoint (M1 audit §11).
///
/// The [list] takes a fixed [AppBreakpoints.listPaneWidth]; [detail] fills the
/// rest, showing [placeholder] while nothing is selected. Callers only build
/// this when [WindowSize.showsTwoPane] is true — on a phone the same screens
/// keep their single-column flow and open detail as a sheet or a pushed route.
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.list,
    required this.detail,
    this.placeholder,
  });

  final Widget list;

  /// The detail pane content, or null when there is no selection.
  final Widget? detail;

  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Traversal (keyboard / switch access) runs the whole list, then the
        // whole detail — never interleaved (WCAG 2.4.3 Focus Order).
        FocusTraversalGroup(
          child: SizedBox(width: AppBreakpoints.listPaneWidth, child: list),
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(
          child: FocusTraversalGroup(
            child:
                detail ??
                placeholder ??
                const PaneWaiting(
                  message: 'Select an item to see its details.',
                ),
          ),
        ),
      ],
    );
  }
}

/// The neutral "nothing selected yet" state for a detail pane.
class PaneWaiting extends StatelessWidget {
  const PaneWaiting({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.touch_app_outlined,
              size: 36,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
