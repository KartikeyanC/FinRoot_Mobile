import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../../navigation/pane_selection.dart';
import '../../../navigation/two_pane.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../sync/application/sync_engine.dart';
import '../application/transactions_providers.dart';
import '../domain/day_group.dart';
import '../domain/transaction.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/day_group_header.dart';
import 'widgets/transaction_tile.dart';

/// The transactions ledger (M8) — grouped by day, filterable by type, text
/// search, and (from an account) by account. Reads the local cache; pull to
/// refresh forces a sync. Tap a row for detail / edit / delete.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(ledgerFilterProvider).search;
    if (existing.isNotEmpty) _search.text = existing;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final twoPane = AppBreakpoints.of(context).showsTwoPane;
    final filter = ref.watch(ledgerFilterProvider);
    final ledger = ref.watch(ledgerProvider);
    final t = Theme.of(context).textTheme;
    final selectedId = twoPane
        ? ref.watch(selectedTransactionIdProvider)
        : null;

    void openRow(String id) {
      if (twoPane) {
        ref.read(selectedTransactionIdProvider.notifier).select(id);
      } else {
        openTransactionDetail(context, id);
      }
    }

    final list = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Transactions', style: t.headlineSmall),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _search,
                    onChanged: (v) =>
                        ref.read(ledgerFilterProvider.notifier).setSearch(v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search notes and categories',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                ref
                                    .read(ledgerFilterProvider.notifier)
                                    .setSearch('');
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TypeChips(
                    selected: filter.type,
                    onSelected: (type) =>
                        ref.read(ledgerFilterProvider.notifier).setType(type),
                  ),
                  if (filter.accountId != null)
                    _AccountFilterBanner(accountId: filter.accountId!),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(syncEngineProvider.notifier)
                    .syncNow(force: true),
                child: ledger.when(
                  loading: () => const LoadingView(),
                  error: (e, _) => ErrorView(e),
                  data: (txns) => txns.isEmpty
                      ? _EmptyLedger(filtered: filter.isActive)
                      : _LedgerList(
                          groups: groupByDay(txns),
                          selectedId: selectedId,
                          onTapRow: openRow,
                        ),
                ),
              ),
            ),
          ],
        );

    if (!twoPane) {
      return Scaffold(body: SafeArea(bottom: false, child: list));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: TwoPane(
          list: list,
          detail: selectedId == null
              ? null
              : TransactionDetailView(
                  id: selectedId,
                  onClose: () => ref
                      .read(selectedTransactionIdProvider.notifier)
                      .clear(),
                ),
          placeholder: const PaneWaiting(
            message: 'Pick a transaction to see its full detail here.',
            icon: Icons.receipt_long_outlined,
          ),
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelected});
  final TxnType? selected;
  final ValueChanged<TxnType?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, TxnType? value) => Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('All', null),
          chip('Income', TxnType.income),
          chip('Expense', TxnType.expense),
          chip('Transfer', TxnType.transfer),
        ],
      ),
    );
  }
}

class _AccountFilterBanner extends ConsumerWidget {
  const _AccountFilterBanner({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountByIdProvider(accountId));
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              account?.name ?? 'Account',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          TextButton(
            onPressed: () =>
                ref.read(ledgerFilterProvider.notifier).setAccount(null),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({
    required this.groups,
    required this.selectedId,
    required this.onTapRow,
  });

  final List<DayGroup> groups;
  final String? selectedId;
  final ValueChanged<String> onTapRow;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final group = groups[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DayGroupHeader(day: group.day),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Column(
                children: [
                  for (var j = 0; j < group.items.length; j++) ...[
                    if (j > 0) const Divider(height: 1),
                    _Tile(
                      txn: group.items[j],
                      selected: group.items[j].id == selectedId,
                      onTap: () => onTapRow(group.items[j].id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.txn,
    required this.selected,
    required this.onTap,
  });

  final TransactionEntity txn;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final row = TransactionTile(txn, showDay: false, onTap: onTap);
    if (!selected) return row;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.card,
      ),
      child: row,
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyView(
          icon: filtered ? Icons.search_off : Icons.receipt_long_outlined,
          title: filtered ? 'No matches' : 'No transactions yet',
          message: filtered
              ? 'Try a different search or filter.'
              : 'Tap + to record your first one.',
        ),
      ],
    );
  }
}
