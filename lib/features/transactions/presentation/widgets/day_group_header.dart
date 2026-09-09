import 'package:flutter/material.dart';

import '../../../../core/time/relative_time.dart';
import '../../../../design/design.dart';

/// The date label above a day's block of transactions in the ledger.
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        top: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        RelativeTime.dayLabel(day),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
