import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// A thin, fully round progress bar (the [SegmentedBar] look, single segment).
/// Private to trackers because the kit's `SegmentedBar` currently paints its
/// segments with zero height inside a loose `Row`.
class TrackerBar extends StatelessWidget {
  const TrackerBar({super.key, required this.fraction, required this.color});

  /// 0..1 (clamped).
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0;
    return ClipRRect(
      borderRadius: AppRadius.chip,
      child: SizedBox(
        height: 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.palette.line),
            if (f > 0)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: f,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.chip,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
