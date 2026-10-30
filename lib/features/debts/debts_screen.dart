import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../accounts/presentation/wealth_kit.dart';
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
    return AppPage(
      title: 'Debts',
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: debts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyView(
                title: 'No debts',
                message:
                    'Loans and EMIs you add on the web dashboard show up '
                    'here, with what is paid and what is left.',
                icon: Icons.account_balance_outlined,
              );
            }
            final open = list.where((d) => !d.isClosed).toList();
            final owed = open.fold<double>(0, (s, d) => s + d.remaining);
            final monthly = open.fold<double>(0, (s, d) => s + d.monthly);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                MetricCard(
                  eyebrow: 'Still owed',
                  figure: MoneyFormat.short(owed),
                  figureSuffix: 'across ${open.length} open',
                  status: '${MoneyFormat.money(monthly)} in EMIs a month',
                  statusColor: context.palette.muted,
                ),
                SectionTitle(
                  'Loans',
                  trailing: Text(
                    '${open.length} of ${list.length} open',
                    style: AppTypography.label.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ),
                for (final d in list) ...[
                  _DebtCard(d),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard(this.debt);
  final Debt debt;

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    DebtInstallment i,
  ) async {
    final money = MoneyFormat.money(i.amount, currency: debt.currency);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Mark EMI ${i.month} paid?'),
        content: Text(
          '$money to ${debt.lender}. This only ticks it off; '
          'add the expense too if you want it in your transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Mark paid'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await markInstallmentPaid(ref, debt, i.month);
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final finance = context.finance;
    final next = debt.nextDue;
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final overdue =
        next?.dueDate != null && next!.dueDate!.isBefore(DateTime.now());

    final Widget pill = debt.isClosed
        ? TonePill('Closed', Tones.mint(context))
        : overdue
        ? TonePill('Overdue', Tones.coral(context))
        : TonePill('Active', Tones.sky(context));
    final tone = debt.isClosed
        ? Tones.mint(context)
        : overdue
        ? Tones.coral(context)
        : Tones.sky(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ToneTile(icon: Icons.account_balance_outlined, tone: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.lender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontSize: 15,
                      ),
                    ),
                    if (debt.category.isNotEmpty)
                      Text(
                        debt.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              pill,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text.rich(
            TextSpan(
              text: MoneyFormat.short(
                debt.paidAmount,
                currency: debt.currency,
              ),
              style: AppTypography.title.copyWith(
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              children: [
                TextSpan(
                  text:
                      '  paid of ${MoneyFormat.short(debt.total, currency: debt.currency)}',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SlimBar(
            value: debt.progress.toDouble(),
            color: debt.isClosed ? finance.success : tone.fg,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${debt.paidCount} of ${debt.duration} EMIs paid · '
            '${MoneyFormat.money(debt.remaining, currency: debt.currency)} left',
            style: AppTypography.label.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: palette.line),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Next: EMI ${next.month} · ${MoneyFormat.money(next.amount, currency: debt.currency)}'
                    '${next.dueDate == null ? '' : ' · due ${_due.format(next.dueDate!)}'}',
                    style: AppTypography.bodyStrong.copyWith(
                      color: overdue ? finance.expense : palette.ink,
                    ),
                  ),
                ),
                if (canWrite) ...[
                  const SizedBox(width: AppSpacing.sm),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _markPaid(context, ref, next),
                    child: const Text('Mark paid'),
                  ),
                ],
              ],
            ),
          ],
          if (debt.notes != null && debt.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              debt.notes!,
              style: AppTypography.label.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
