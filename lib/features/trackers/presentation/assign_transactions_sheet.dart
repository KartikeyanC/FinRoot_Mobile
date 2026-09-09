import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
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
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text('Assign transactions', style: tt.titleLarge),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              'Untagged transactions from within this tracker\'s dates. '
              'Assigning only adds a label — no money moves.',
              style: tt.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
                  ? const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Text('Nothing untagged in this date range.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: txns.length,
                      itemBuilder: (_, i) {
                        final txn = txns[i];
                        final checked = _selected.contains(txn.id);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: _busy
                              ? null
                              : (v) => setState(() {
                                  v == true
                                      ? _selected.add(txn.id)
                                      : _selected.remove(txn.id);
                                }),
                          title: Text(
                            txn.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${txn.category} · '
                            '${RelativeTime.dayLabel(txn.occurredAt)}',
                          ),
                          secondary: AmountText.money(
                            txn.amount,
                            type: txn.type,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        ],
      ),
    );
  }
}
