import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../domain/tracker_draft.dart';
import '../../domain/tracker_spend.dart';

/// The status pill on a tracker card / header: lifecycle for completed and
/// archived trackers, budget health for live ones.
class TrackerStatusPill extends StatelessWidget {
  const TrackerStatusPill(this.t, {super.key});

  final TrackerWithSpend t;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    (Color, Color) mint() => (
      dark ? AppColors.mintDark : AppColors.mintLight,
      dark ? AppColors.mintFgDark : AppColors.mintFgLight,
    );
    (Color, Color) coral() => (
      dark ? AppColors.coralDark : AppColors.coralLight,
      dark ? AppColors.coralFgDark : AppColors.coralFgLight,
    );
    (Color, Color) butter() => (
      dark ? AppColors.butterDark : AppColors.butterLight,
      dark ? AppColors.butterFgDark : AppColors.butterFgLight,
    );
    (Color, Color) sky() => (
      dark ? AppColors.skyDark : AppColors.skyLight,
      dark ? AppColors.skyFgDark : AppColors.skyFgLight,
    );

    final status = TrackerStatus.fromWire(t.tracker.status);
    final String label;
    final (Color, Color) c;
    if (status == TrackerStatus.completed) {
      label = 'Completed';
      c = sky();
    } else if (status == TrackerStatus.archived) {
      label = 'Archived';
      c = (context.palette.subtle, context.palette.muted);
    } else if (t.hasBudget && t.isOverBudget) {
      label = 'Over budget';
      c = coral();
    } else if (t.hasBudget && t.utilization >= 85) {
      label = 'Near limit';
      c = butter();
    } else if (t.hasBudget) {
      label = 'On track';
      c = mint();
    } else {
      label = 'Active';
      c = mint();
    }
    return StatusPill(label, background: c.$1, foreground: c.$2, dot: true);
  }
}
