import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../../navigation/quick_add_entry.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../quick_add/application/quick_add_controller.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../../trackers/application/tracker_editor_controller.dart';
import '../../trackers/application/trackers_providers.dart';
import '../../trackers/presentation/tracker_picker_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/transactions_providers.dart';
import '../domain/transaction.dart';

/// Opens the transaction detail the right way for the window size (M1 audit
/// §11): a bottom sheet on a phone, a centred dialog on a tablet. The
/// Transactions tab skips this and shows the detail inline in its second pane
/// (see [TransactionDetailView]).
Future<void> openTransactionDetail(BuildContext context, String id) {
  if (AppBreakpoints.of(context).isExpanded) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 480,
          child: TransactionDetailView(
            id: id,
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => TransactionDetailView(
      id: id,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// The transaction detail body — amount, meta rows, edit / delete. A bottom
/// sheet and a tablet dialog wrap it (via [openTransactionDetail]); the
/// Transactions two-pane layout drops it straight into its detail pane.
/// [onClose] runs after a successful delete — pop the sheet, or clear the
/// pane selection.
class TransactionDetailView extends ConsumerWidget {
  const TransactionDetailView({super.key, required this.id, this.onClose});

  final String id;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txn = ref.watch(transactionByIdProvider(id)).value;
    final t = Theme.of(context).textTheme;

    if (txn == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Center(child: Text('This transaction is no longer here.')),
      );
    }

    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final isTransfer = txn.type == TxnType.transfer;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: AmountText.money(
              txn.amount,
              type: txn.type,
              size: AmountSize.hero,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              isTransfer ? 'Transfer' : txn.category,
              style: t.titleMedium,
            ),
          ),
          if (txn.isPending || txn.hasFailedSync) ...[
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: Text(
                txn.hasFailedSync ? 'Not synced yet' : 'Pending sync',
                style: t.labelSmall?.copyWith(
                  color: txn.hasFailedSync
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _Row(
            label: 'Date',
            value:
                '${RelativeTime.dayLabel(txn.occurredAt)} · '
                '${TimeOfDay.fromDateTime(txn.occurredAt.toLocal()).format(context)}',
          ),
          if (!isTransfer && txn.paymentMode != null)
            _Row(label: 'Payment mode', value: txn.paymentMode!),
          if (isTransfer) ...[
            _AccountRow(label: 'From', accountId: txn.accountId),
            _AccountRow(label: 'To', accountId: txn.transferToAccountId),
          ] else
            _AccountRow(label: 'Account', accountId: txn.accountId),
          if (!isTransfer) _TrackerRow(txn: txn, canWrite: canWrite),
          if ((txn.description ?? '').trim().isNotEmpty)
            _Row(label: 'Note', value: txn.description!.trim()),
          const SizedBox(height: AppSpacing.lg),
          if (canWrite)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openQuickAdd(
                      context,
                      kind: QuickAddKind.values.byName(txn.type.name),
                      editing: txn,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmDelete(context, ref, txn),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TransactionEntity txn,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text(
          'It will be removed everywhere once the change syncs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(quickAddControllerProvider).deleteTransaction(txn.id);
      onClose?.call();
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction deleted')),
      );
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.label, required this.accountId});
  final String label;
  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accountId == null) {
      return _Row(label: label, value: 'Not set');
    }
    final account = ref.watch(accountByIdProvider(accountId!));
    return _Row(
      label: label,
      value: account?.name ?? 'Deleted account',
    );
  }
}

class _TrackerRow extends ConsumerWidget {
  const _TrackerRow({required this.txn, required this.canWrite});
  final TransactionEntity txn;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } on Failure catch (f) {
        messenger.showSnackBar(SnackBar(content: Text(f.message)));
      }
    }

    if (txn.trackerId == null) {
      if (!canWrite) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => run(() async {
              final id = await pickTracker(context);
              if (id == null) return;
              await ref
                  .read(trackerEditorControllerProvider)
                  .assign(id, [txn.id]);
            }),
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Assign to a tracker'),
          ),
        ),
      );
    }

    final tracker = ref.watch(trackerByIdProvider(txn.trackerId!)).value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              'Tracker',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: tracker == null
                  ? null
                  : () => context.push('/tracker/${txn.trackerId}'),
              child: Text(
                tracker == null
                    ? 'Assigned'
                    : trackerDisplayLabel(tracker.name),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tracker == null ? null : scheme.primary,
                ),
              ),
            ),
          ),
          if (canWrite)
            TextButton(
              onPressed: () => run(
                () => ref
                    .read(trackerEditorControllerProvider)
                    .unassign(txn.id),
              ),
              child: const Text('Remove'),
            ),
        ],
      ),
    );
  }
}
