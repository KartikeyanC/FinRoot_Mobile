import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../domain/split_dues.dart';

/// `split_dues` is not in the database yet.
class SplitDuesMissingView extends StatelessWidget {
  const SplitDuesMissingView({super.key});

  @override
  Widget build(BuildContext context) => const EmptyView(
    icon: Icons.construction_outlined,
    title: "Who owes what isn't switched on yet",
    message: kSplitDuesMissingMessage,
  );
}

/// These screens read the server live (like Net worth): offline, say so.
class OnlineOnlyView extends StatelessWidget {
  const OnlineOnlyView({super.key, required this.feature});
  final String feature;

  @override
  Widget build(BuildContext context) => EmptyView(
    icon: Icons.cloud_off_outlined,
    title: "You're offline",
    message: '$feature needs a connection. Connect, then pull to refresh.',
  );
}

/// A small inline note (amber for warnings).
class InlineNote extends StatelessWidget {
  const InlineNote(this.text, {super.key, this.warning = false, this.icon});
  final String text;
  final bool warning;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = warning ? context.finance.warning : context.palette.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon ?? (warning ? Icons.info_outline : Icons.check_circle_outline),
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
