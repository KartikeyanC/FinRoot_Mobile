import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../navigation/quick_add_entry.dart';
import '../../../quick_add/domain/quick_add_draft.dart';

/// Three fast paths into capture, straight from the feed. Quick Add is the
/// highest-priority interaction (brief §7); the centre FAB is always there, but
/// a person landing on Home should be one tap from the common cases.
///
/// M6 opens the shared Quick Add surface; M7 builds the amount-first capture
/// behind it and will take the pre-selected kind.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    return Row(
      children: [
        _Action(
          label: 'Expense',
          icon: Icons.south_west_rounded,
          color: finance.expense,
          onTap: () => openQuickAdd(context),
        ),
        const SizedBox(width: AppSpacing.md),
        _Action(
          label: 'Income',
          icon: Icons.north_east_rounded,
          color: finance.income,
          onTap: () => openQuickAdd(context, kind: QuickAddKind.income),
        ),
        const SizedBox(width: AppSpacing.md),
        _Action(
          label: 'Transfer',
          icon: Icons.swap_horiz_rounded,
          color: finance.transfer,
          onTap: () => openQuickAdd(context, kind: QuickAddKind.transfer),
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
