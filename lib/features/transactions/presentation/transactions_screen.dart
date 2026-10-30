import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_format.dart';
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

    final list = AppPage(
      title: 'Transactions',
      subtitle: ledger.value == null || ledger.value!.isEmpty
          ? null
          : '${ledger.value!.length} ${ledger.value!.length == 1 ? 'entry' : 'entries'}${filter.isActive ? ' match' : ''}',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SearchField(
            controller: _search,
            onChanged: (v) =>
                ref.read(ledgerFilterProvider.notifier).setSearch(v),
            onClear: () {
              _search.clear();
              ref.read(ledgerFilterProvider.notifier).setSearch('');
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _TypeChips(
            selected: filter.type,
            onSelected: (type) =>
                ref.read(ledgerFilterProvider.notifier).setType(type),
          ),
        ],
      ),
      padBody: false,
      body: SwipeTabs(
        index: _typeOrder.indexOf(filter.type),
        count: _typeOrder.length,
        onChanged: (i) =>
            ref.read(ledgerFilterProvider.notifier).setType(_typeOrder[i]),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(syncEngineProvider.notifier).syncNow(force: true),
          child: ledger.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(e),
            data: (txns) => _LedgerList(
              txns: txns,
              filter: filter,
              selectedId: selectedId,
              onTapRow: openRow,
            ),
          ),
        ),
      ),
    );

    if (!twoPane) return list;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: TwoPane(
          list: list,
          detail: selectedId == null
              ? null
              : TransactionDetailView(
                  id: selectedId,
                  onClose: () =>
                      ref.read(selectedTransactionIdProvider.notifier).clear(),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: AppRadius.chip,
      borderSide: BorderSide(color: c),
    );
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search notes and categories',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: palette.card,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          enabledBorder: border(palette.line),
          focusedBorder: border(palette.accent),
          border: border(palette.line),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
        ),
      ),
    );
  }
}

/// Chip order, which is also the swipe order (null = All).
const _typeOrder = <TxnType?>[
  null,
  TxnType.income,
  TxnType.expense,
  TxnType.transfer,
];

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelected});
  final TxnType? selected;
  final ValueChanged<TxnType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterPills<TxnType?>(
      options: const [
        FilterPill<TxnType?>(null, 'All'),
        FilterPill<TxnType?>(TxnType.income, 'Income'),
        FilterPill<TxnType?>(TxnType.expense, 'Expense'),
        FilterPill<TxnType?>(TxnType.transfer, 'Transfer'),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _AccountFilterBanner extends ConsumerWidget {
  const _AccountFilterBanner({required this.accountId});
  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountByIdProvider(accountId));
    return InfoPill(
      icon: Icons.filter_alt_rounded,
      text: account?.name ?? 'Account',
      detail: 'Filtered by account',
      onClose: () => ref.read(ledgerFilterProvider.notifier).setAccount(null),
    );
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({
    required this.txns,
    required this.filter,
    required this.selectedId,
    required this.onTapRow,
  });

  final List<TransactionEntity> txns;
  final LedgerFilter filter;
  final String? selectedId;
  final ValueChanged<String> onTapRow;

  @override
  Widget build(BuildContext context) {
    final groups = groupByDay(txns);
    var income = Decimal.zero;
    var expense = Decimal.zero;
    for (final t in txns) {
      if (t.type == TxnType.income) income += t.amount.toInrMoney().amount;
      if (t.type == TxnType.expense) expense += t.amount.toInrMoney().amount;
    }
    final net = income - expense;
    final finance = context.finance;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        96,
      ),
      children: [
        if (filter.accountId != null) ...[
          _AccountFilterBanner(accountId: filter.accountId!),
          const SizedBox(height: AppSpacing.md),
        ],
        if (txns.isEmpty)
          _EmptyLedger(filtered: filter.isActive)
        else ...[
          StatStrip([
            Stat(
              MoneyFormat.short(income.toDouble()),
              'In',
              color: finance.income,
            ),
            Stat(
              MoneyFormat.short(expense.toDouble()),
              'Out',
              color: finance.expense,
            ),
            Stat(
              MoneyFormat.short(net.toDouble()),
              'Net',
              color: net < Decimal.zero ? finance.expense : null,
            ),
          ]),
          for (final group in groups) ...[
            DayGroupHeader(day: group.day),
            for (final txn in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TransactionTile(
                  txn,
                  card: true,
                  selected: txn.id == selectedId,
                  onTap: () => onTapRow(txn.id),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: CardEmpty(
        icon: filtered ? Icons.search_off_rounded : Icons.receipt_long_rounded,
        title: filtered ? 'No matches' : 'No transactions yet',
        message: filtered
            ? 'Try a different search or filter.'
            : 'Tap + to record your first one.',
      ),
    );
  }
}
