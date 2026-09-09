import 'package:flutter/material.dart';

import '../design/tokens/app_breakpoints.dart';
import '../features/quick_add/domain/quick_add_draft.dart';
import '../features/quick_add/presentation/quick_add_sheet.dart';

/// Opens Quick Add the right way for the current window size (M1 audit §11):
/// a bottom sheet on a phone, a centered dialog on a tablet. [kind] pre-selects
/// the Expense / Income / Transfer segment.
Future<void> openQuickAdd(
  BuildContext context, {
  QuickAddKind kind = QuickAddKind.expense,
}) {
  final expanded = AppBreakpoints.of(context).isExpanded;
  if (expanded) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(width: 460, child: QuickAddSheet(initialKind: kind)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => QuickAddSheet(initialKind: kind),
  );
}
