import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/widgets/category_style.dart';
import '../application/tracker_editor_controller.dart';
import '../application/trackers_providers.dart';

/// Pick untagged transactions inside a tracker's date window and assign them.
/// One bulk write, replay-safe (`tracker_id IS NULL` guard). No balance moves.
Future<void> openAssignTransactions(BuildContext context, String trackerId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AssignSheet(trackerId: trackerId),
  );
}

class _AssignSheet extends ConsumerStatefulWidget {
  const _AssignSheet({required this.trackerId});
  final String trackerId;

  @override
  ConsumerState<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<_AssignSheet> {
  final _selected = <String>{};
  bool _busy = false;

  Future<void> _assign() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(trackerEditorControllerProvider)
          .assign(widget.trackerId, _selected.toList());
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${_selected.length} '
            '${_selected.length == 1 ? 'transaction' : 'transactions'} assigned. '
            'Account balances unchanged.',
          ),
        ),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ref.watch(untaggedForTrackerProvider(widget.trackerId));
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Assign transactions',
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Untagged transactions from within this tracker\'s dates. '
            'Assigning only adds a label — no money moves.',
            style: AppTypography.body.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: candidates.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: LoadingView(),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ErrorView(e, stackTrace: st),
              ),
              data: (txns) => txns.isEmpty
                  ? const CardEmpty(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Nothing untagged',
                      message: 'Nothing untagged in this date range.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: txns.length,
                      itemBuilder: (_, i) {
                        final txn = txns[i];
                        final checked = _selected.contains(txn.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _AssignRow(
                            txn: txn,
                            checked: checked,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    v
                                        ? _selected.add(txn.id)
                                        : _selected.remove(txn.id);
                                  }),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _busy || _selected.isEmpty ? null : _assign,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _selected.isEmpty
                        ? 'Select transactions'
                        : 'Assign ${_selected.length}',
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _AssignRow extends StatelessWidget {
  const _AssignRow({
    required this.txn,
    required this.checked,
    required this.onChanged,
  });

  final TransactionEntity txn;
  final bool checked;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      checked: checked,
      child: ListRow(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CategoryTile(category: txn.category, type: txn.type),
            if (checked)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.card, width: 2),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: palette.onAccent,
                  ),
                ),
              ),
          ],
        ),
        title: txn.title,
        subtitle:
            '${txn.category} · ${RelativeTime.dayLabel(txn.occurredAt)}',
        trailing: AmountText.money(txn.amount, type: txn.type),
        onTap: onChanged == null ? null : () => onChanged!(!checked),
      ),
    );
  }
}
