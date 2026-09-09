import 'package:flutter/widgets.dart';

/// Size classes (Material 3 window size classes, trimmed to what FinRoot uses).
///
/// One Flutter codebase, layout adapts by width — never a separate phone/tablet
/// build (see M1 audit §11, §28).
enum WindowSize {
  /// Phones in portrait. Bottom navigation, full-screen flows, bottom sheets.
  compact,

  /// Large phones, small tablets, phones in landscape. Bottom nav retained,
  /// wider content, occasional two-column lists.
  medium,

  /// Tablets. NavigationRail + list/detail split views. Quick Add as a dialog.
  expanded;

  bool get isCompact => this == WindowSize.compact;
  bool get isExpanded => this == WindowSize.expanded;

  /// Expanded swaps the bottom bar for a [NavigationRail].
  bool get showsRail => this == WindowSize.expanded;

  /// Expanded is wide enough to hold a list beside its detail. The list
  /// screens (Transactions, Trackers, More) render two panes here; narrower
  /// sizes keep the phone flow (sheet / pushed route).
  bool get showsTwoPane => this == WindowSize.expanded;
}

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  /// At/above this the rail shows its labels inline ([NavigationRail.extended])
  /// and gets room for a workspace + settings footer.
  static const double railExtended = 1000;

  /// A single reading column never grows past this — a full-bleed paragraph or
  /// form on a wide tablet is hard to scan. Feeds and detail panes centre
  /// their content within it.
  static const double contentMaxWidth = 720;

  /// Preferred width of the list pane in a two-pane layout; the detail pane
  /// takes the rest.
  static const double listPaneWidth = 372;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  /// Whether the rail should render with inline labels at this width.
  static bool railExtendedAt(double width) => width >= railExtended;
}
