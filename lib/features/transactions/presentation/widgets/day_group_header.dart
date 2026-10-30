import 'package:flutter/material.dart';

import '../../../../core/time/relative_time.dart';
import '../../../../design/design.dart';

/// The date heading above a day's block of transactions in the ledger.
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) =>
      SectionTitle(RelativeTime.dayLabel(day));
}
