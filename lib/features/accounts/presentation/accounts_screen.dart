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

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openAccountForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Account'),
            )
          : null,
      body: accountsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(e),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyView(
              icon: Icons.account_balance_outlined,
              title: 'No accounts yet',
              message: 'Add your bank, cash and cards to track their balances.',
              action: canWrite
                  ? FilledButton(
                      onPressed: () => openAccountForm(context),
                      child: const Text('Add an account'),
                    )
                  : null,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.huge,
            ),
            children: [
              _TotalCard(
                total: ref.watch(totalBalanceProvider),
                stale: summary.isLoading && summary.value == null,
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final account in accounts)
                _AccountTile(
                  account: account,
                  balance: balances[account.id] ?? Money.zero(),
                  canWrite: canWrite,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.stale});
  final Money total;
  final bool stale;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total across accounts',
            style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          AmountText.money(total, size: AmountSize.hero, signed: false),
          if (stale) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Balancing figures update on the next sync.',
              style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => _openLedger(context, ref),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.secondaryContainer,
              child: Icon(
                _iconFor(account.type),
                size: 20,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    account.typeLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(child: AmountText.money(balance, signed: false)),
            if (canWrite)
              PopupMenuButton<String>(
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
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'ledger', child: Text('View transactions')),
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: const Text(
          'Transactions linked to it are kept, but they will no longer count '
          'towards an account balance.',
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
      await ref.read(accountEditorControllerProvider).delete(account.id);
      messenger.showSnackBar(const SnackBar(content: Text('Account deleted')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }

  IconData _iconFor(String type) => switch (type) {
    'bank' => Icons.account_balance_outlined,
    'debit' || 'credit' => Icons.credit_card_outlined,
    'wallet' => Icons.account_balance_wallet_outlined,
    'cash' => Icons.payments_outlined,
    'investment' => Icons.trending_up,
    _ => Icons.savings_outlined,
  };
}
