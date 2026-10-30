import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Pastel background / text pair for a [StatusPill] or an [IconTile], resolved
/// for the current brightness (mint = ok, butter = soon, coral = late).
class StatusTone {
  const StatusTone(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static StatusTone mint(BuildContext context) => context.palette.isDark
      ? const StatusTone(AppColors.mintDark, AppColors.mintFgDark)
      : const StatusTone(AppColors.mintLight, AppColors.mintFgLight);

  static StatusTone butter(BuildContext context) => context.palette.isDark
      ? const StatusTone(AppColors.butterDark, AppColors.butterFgDark)
      : const StatusTone(AppColors.butterLight, AppColors.butterFgLight);

  static StatusTone coral(BuildContext context) => context.palette.isDark
      ? const StatusTone(AppColors.coralDark, AppColors.coralFgDark)
      : const StatusTone(AppColors.coralLight, AppColors.coralFgLight);

  /// Quiet grey-ish tone for "later" and "off".
  static StatusTone neutral(BuildContext context) =>
      StatusTone(context.palette.subtle, context.palette.muted);

  /// A due-date tone from whole days until due (negative = overdue).
  static StatusTone forDays(BuildContext context, int days) {
    if (days < 0) return coral(context);
    if (days <= 7) return butter(context);
    return neutral(context);
  }

  StatusPill pill(String label, {bool dot = false}) =>
      StatusPill(label, background: background, foreground: foreground, dot: dot);
}

/// "3d overdue" / "Due today" / "Due tomorrow" / "Due in 5d".
String dueLabel(int days) => switch (days) {
  < 0 => '${-days}d overdue',
  0 => 'Due today',
  1 => 'Due tomorrow',
  _ => 'Due in ${days}d',
};
