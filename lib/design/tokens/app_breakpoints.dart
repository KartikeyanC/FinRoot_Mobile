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
  bool get showsRail => this == WindowSize.expanded;
}

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }
}
