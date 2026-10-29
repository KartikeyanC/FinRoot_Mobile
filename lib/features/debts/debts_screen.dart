import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../sync/application/sync_engine.dart';
import '../workspace/application/workspace_providers.dart';
import 'debts.dart';

final _due = DateFormat('d MMM yyyy');

/// Debts / EMIs — the web dashboard's Debts page on the phone: what's paid,
/// what's left, the next instalment, and "Mark paid". New debts are still
/// added on the web.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debts = ref.watch(debtsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Debts')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: debts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: AppSpacing.huge),
                EmptyView(
                  title: 'No debts',
                  message: 'Loans and EMIs you add on the web dashboard show up here.',
                  icon: Icons.account_balance_outlined,
                ),
              ]);
            }
            final open = list.where((d) => !d.isClosed).toList();
            final owed = open.fold<double>(0, (s, d) => s + d.remaining);
            final monthly = open.fold<double>(0, (s, d) => s + d.monthly);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter, AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.huge,
              ),
              children: [
                AppCard(
                  child: Row(
                    children: [
                      Expanded(child: _Stat('Still owed', MoneyFormat.money(owed))),
                      Expanded(child: _Stat('EMIs a month', MoneyFormat.money(monthly))),
                      Expanded(child: _Stat('Open', '${open.length} of ${list.length}')),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final d in list) ...[
                  _DebtCard(d),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.labelMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(value, style: tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard(this.debt);
  final Debt debt;

  Future<void> _markPaid(BuildContext context, WidgetRef ref, DebtInstallment i) async {
    final money = MoneyFormat.money(i.amount, currency: debt.currency);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Mark EMI ${i.month} paid?'),
        content: Text('$money to ${debt.lender}. This only ticks it off; '
            'add the expense too if you want it in your transactions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Mark paid')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await markInstallmentPaid(ref, debt, i.month);
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final next = debt.nextDue;
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final overdue = next?.dueDate != null && next!.dueDate!.isBefore(DateTime.now());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(debt.lender, style: tt.titleMedium)),
              if (debt.isClosed)
                Text('Closed', style: tt.labelMedium?.copyWith(color: scheme.primary)),
            ],
          ),
          if (debt.category.isNotEmpty) Text(debt.category, style: tt.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(value: debt.progress, minHeight: 6),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${MoneyFormat.money(debt.paidAmount, currency: debt.currency)} paid of '
            '${MoneyFormat.money(debt.total, currency: debt.currency)} · '
            '${debt.paidCount}/${debt.duration} EMIs',
            style: tt.bodySmall,
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next: EMI ${next.month} · ${MoneyFormat.money(next.amount, currency: debt.currency)}'
                    '${next.dueDate == null ? '' : ' · due ${_due.format(next.dueDate!)}'}',
                    style: tt.bodyMedium?.copyWith(color: overdue ? scheme.error : null),
                  ),
                ),
                if (canWrite)
                  TextButton(
                    onPressed: () => _markPaid(context, ref, next),
                    child: const Text('Mark paid'),
                  ),
              ],
            ),
          ],
          if (debt.notes != null && debt.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(debt.notes!, style: tt.bodySmall),
          ],
        ],
      ),
    );
  }
}
