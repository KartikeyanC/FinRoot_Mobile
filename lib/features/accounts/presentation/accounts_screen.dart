import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../navigation/destinations.dart';
import '../../summary/application/summary_providers.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/account_editor_controller.dart';
import '../application/accounts_providers.dart';
import '../domain/account.dart';
import 'account_form_sheet.dart';
import 'wealth_kit.dart';

/// Accounts (M8) — the list, each with its live balance
/// (`opening_balance + dashboard_summary` delta), plus add / edit / delete.
/// Reached from More; account writes are online-only in V1.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(workspaceAccountsProvider);
    final balances = ref.watch(accountBalancesProvider);
    final summary = ref.watch(workspaceSummaryProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasAccounts = accountsAsync.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Accounts',
      padBody: false,
      floatingActionButton: canWrite && hasAccounts
          ? AddFab(label: 'Account', onPressed: () => openAccountForm(context))
          : null,
      body: accountsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyView(
              icon: Icons.account_balance_outlined,
              title: 'No accounts yet',
              message:
                  'Add your bank, cash and cards to see every balance in one '
                  'place.',
              action: canWrite
                  ? FilledButton(
                      onPressed: () => openAccountForm(context),
                      child: const Text('Add an account'),
                    )
                  : null,
            );
          }
          final assets = [
            for (final a in accounts)
              if (!_isLiability(a)) a,
          ];
          final cards = [
            for (final a in accounts)
              if (_isLiability(a)) a,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.xs,
              AppSpacing.screenGutter,
              96,
            ),
            children: [
              _TotalCard(
                total: ref.watch(totalBalanceProvider),
                accounts: accounts,
                balances: balances,
                stale: summary.isLoading && summary.value == null,
              ),
              if (assets.isNotEmpty) ...[
                SectionTitle('Cash and bank', trailing: _Count(assets.length)),
                for (final account in assets)
                  _AccountTile(
                    account: account,
                    balance: balances[account.id] ?? Money.zero(),
                    canWrite: canWrite,
                  ),
              ],
              if (cards.isNotEmpty) ...[
                SectionTitle('Credit cards', trailing: _Count(cards.length)),
                for (final account in cards)
                  _AccountTile(
                    account: account,
                    balance: balances[account.id] ?? Money.zero(),
                    canWrite: canWrite,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

bool _isLiability(AccountEntity a) => a.type == 'credit';

class _Count extends StatelessWidget {
  const _Count(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Text(
    n == 1 ? '1 account' : '$n accounts',
    style: AppTypography.label.copyWith(color: context.palette.muted),
  );
}

Tone _toneFor(BuildContext c, String type) => switch (type) {
  'bank' => Tones.sky(c),
  'cash' => Tones.mint(c),
  'wallet' => Tones.violet(c),
  'investment' => Tones.teal(c),
  'credit' => Tones.coral(c),
  'debit' => Tones.butter(c),
  _ => Tones.accent(c),
};

IconData _iconFor(String type) => switch (type) {
  'bank' => Icons.account_balance_outlined,
  'debit' || 'credit' => Icons.credit_card_outlined,
  'wallet' => Icons.account_balance_wallet_outlined,
  'cash' => Icons.payments_outlined,
  'investment' => Icons.trending_up,
  _ => Icons.savings_outlined,
};

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.total,
    required this.accounts,
    required this.balances,
    required this.stale,
  });
  final Money total;
  final List<AccountEntity> accounts;
  final Map<String, Money> balances;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Positive balances by account type, for the split bar.
    final byType = <String, double>{};
    for (final a in accounts) {
      final v = (balances[a.id] ?? Money.zero()).amount.toDouble();
      if (v > 0 && !_isLiability(a)) {
        byType[a.typeLabel] = (byType[a.typeLabel] ?? 0) + v;
      }
    }
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      palette.accent,
      Tones.sky(context).fg,
      Tones.butter(context).fg,
      Tones.violet(context).fg,
      Tones.rose(context).fg,
      Tones.teal(context).fg,
    ];
    return MetricCard(
      eyebrow: 'Total across accounts',
      figure: total.formatShort(),
      status: stale
          ? 'Balancing figures update on the next sync.'
          : (accounts.length == 1
                ? '1 account'
                : '${accounts.length} accounts'),
      statusColor: stale ? context.finance.warning : palette.muted,
      child: entries.length > 1
          ? SplitBar([
              for (var i = 0; i < entries.length; i++)
                BarSegment(
                  entries[i].key,
                  entries[i].value,
                  colors[i % colors.length],
                ),
            ])
          : null,
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.balance,
    required this.canWrite,
  });

  final AccountEntity account;
  final Money balance;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final liability = _isLiability(account);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListRow(
        onTap: () => _openLedger(context, ref),
        leading: ToneTile(
          icon: _iconFor(account.type),
          tone: _toneFor(context, account.type),
        ),
        title: account.name,
        subtitle: account.typeLabel,
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.5,
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AmountText(
                balance.amount.toDouble(),
                currency: balance.currency,
                color: liability ? finance.expense : null,
              ),
            ),
            if (canWrite)
              RowMenu(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      openAccountForm(context, editing: account);
                    case 'ledger':
                      _openLedger(context, ref);
                    case 'delete':
                      _confirmDelete(context, ref);
                  }
                },
                items: const [
                  PopupMenuItem(
                    value: 'ledger',
                    child: Text('View transactions'),
                  ),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
        ),
      ),
    );
  }

  void _openLedger(BuildContext context, WidgetRef ref) {
    ref.read(ledgerFilterProvider.notifier).clear();
    ref.read(ledgerFilterProvider.notifier).setAccount(account.id);
    context.go(AppDestination.transactions.path);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${account.name}?',
      message:
          'Transactions linked to it are kept, but they will no longer count '
          'towards an account balance.',
    );
    if (!ok) return;
    try {
      await ref.read(accountEditorControllerProvider).delete(account.id);
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}
