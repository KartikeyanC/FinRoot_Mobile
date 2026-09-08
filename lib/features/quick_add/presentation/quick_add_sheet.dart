import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Quick Add — the highest-priority interaction (brief §7). M7 builds the
/// amount-first Expense / Income / Transfer capture. M2 ships the presentation
/// seam only: `openQuickAdd(context)` shows this as a sheet (phone) or dialog
/// (tablet).
class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final option in const [
            ('Expense', Icons.south_west_rounded),
            ('Income', Icons.north_east_rounded),
            ('Transfer', Icons.swap_horiz_rounded),
            ('Scan bill', Icons.document_scanner_outlined),
            ('Voice', Icons.mic_none_rounded),
          ])
            ListTile(
              leading: Icon(option.$2),
              title: Text(option.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _notReady(context, option.$1),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Capture flows arrive in M7 (Expense / Income / Transfer), '
            'M13 (Scan) and M14 (Voice).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _notReady(BuildContext context, String what) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$what capture is coming soon.')));
  }
}
