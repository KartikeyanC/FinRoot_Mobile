import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_format.dart';
import '../../../core/time/relative_time.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../../navigation/pane_selection.dart';
import '../../../navigation/two_pane.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../privacy/income_privacy.dart';
import '../../quick_add/application/quick_add_controller.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/transactions_providers.dart';
import '../domain/day_group.dart';
import '../domain/ledger_range.dart';
import '../domain/transaction.dart';
import 'transaction_detail_sheet.dart';
import 'widgets/ledger_filters.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/txn_words.dart';

/// The transactions ledger (M8) — grouped by day, filterable by type, text
/// search, date range, category and (from an account) by account. Reads the local cache; pull to
/// refresh forces a sync. Tap a row for detail / edit / delete; long-press to
/// tick several and delete them together. Flat rows from ledger_kit, the
/// same layout as Investments.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  final _selection = BulkSelection();

  @override
  void initState() {
    super.initState();
    final existing = ref.read(ledgerFilterProvider).search;
    if (existing.isNotEmpty) _search.text = existing;
  }

  @override
  void dispose() {
    _search.dispose();
    _selection.dispose();
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
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final shown = [
      for (final t in ledger.value ?? const <TransactionEntity>[]) t.id,
    ];

    void openRow(String id) {
      if (_selection.active) {
        _selection.toggle(id);
      } else if (twoPane) {
        ref.read(selectedTransactionIdProvider.notifier).select(id);
      } else {
        openTransactionDetail(context, id);
      }
    }

    final list = AppPage(
      title: 'Transactions',
      actions: const [IncomePrivacyButton()],
      subtitle: ledger.value == null || ledger.value!.isEmpty
          ? null
          : '${ledger.value!.length} ${ledger.value!.length == 1 ? 'entry' : 'entries'}${filter.isActive ? ' match' : ''}',
      header: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => _selection.active
            ? SelectionBar(
                selection: _selection,
                shown: shown,
                onDelete: () => _deleteSelected(selectedId),
              )
            : Column(
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
                  const SizedBox(height: AppSpacing.sm),
                  const LedgerFilterBar(),
                ],
              ),
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
            data: (txns) => ListenableBuilder(
              listenable: _selection,
              builder: (context, _) => _LedgerList(
                txns: txns,
                filter: filter,
                selectedId: selectedId,
                selection: _selection,
                onTapRow: openRow,
                onLongPressRow: canWrite ? _selection.start : null,
              ),
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

extension on _TransactionsScreenState {
  Future<void> _deleteSelected(String? openId) async {
    final ticked = _selection.ids;
    final done = await deleteSelected(
      context,
      selection: _selection,
      one: 'transaction',
      many: 'transactions',
      delete: ref.read(quickAddControllerProvider).deleteTransaction,
    );
    // The open detail pane may have shown one of them.
    if (done > 0 &&
        openId != null &&
        ticked.contains(openId) &&
        !_selection.contains(openId)) {
      ref.read(selectedTransactionIdProvider.notifier).clear();
    }
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

class _LedgerList extends ConsumerWidget {
  const _LedgerList({
    required this.txns,
    required this.filter,
    required this.selectedId,
    required this.selection,
    required this.onTapRow,
    required this.onLongPressRow,
  });

  final List<TransactionEntity> txns;
  final LedgerFilter filter;
  final String? selectedId;
  final BulkSelection selection;
  final ValueChanged<String> onTapRow;
  final ValueChanged<String>? onLongPressRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(incomePrivacyProvider).masked;
    final groups = groupByDay(txns);
    var income = Decimal.zero;
    var expense = Decimal.zero;
    for (final t in txns) {
      if (t.type == TxnType.income) income += t.amount.toInrMoney().amount;
      if (t.type == TxnType.expense) expense += t.amount.toInrMoney().amount;
    }
    final net = (income - expense).toDouble();
    const gutter = EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter);
    final range = filter.range;
    final pastCache =
        range != null && startsBeforeCache(range.from, DateTime.now());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: 96),
      children: [
        if (filter.accountId != null)
          Padding(
            padding: gutter.copyWith(bottom: AppSpacing.md),
            child: _AccountFilterBanner(accountId: filter.accountId!),
          ),
        if (pastCache)
          Padding(
            padding: gutter.copyWith(bottom: AppSpacing.md),
            child: const LedgerCacheNotice(),
          ),
        if (txns.isEmpty)
          Padding(
            padding: gutter,
            child: _EmptyLedger(filtered: filter.isActive),
          )
        else ...[
          Padding(
            padding: gutter.copyWith(bottom: AppSpacing.lg),
            child: SummaryPanel(
              left: (
                'Money in',
                masked ? kIncomeMask : MoneyFormat.money(income.toDouble()),
              ),
              right: ('Money out', MoneyFormat.money(expense.toDouble())),
              footLabel: 'Net',
              // Net = income − spending, so it would give income away.
              footValue: masked ? kIncomeMask : _signed(net),
              footColor: masked ? null : signColor(context, net),
            ),
          ),
          for (final group in groups) ...[
            LedgerBand(
              title: RelativeTime.dayLabel(group.day),
              count: group.items.length,
              value: masked && group.items.any((t) => t.type == TxnType.income)
                  ? kIncomeMask
                  : _dayNet(group.items),
            ),
            const LedgerDivider(),
            for (final txn in group.items) ...[
              _TxnRow(
                txn: txn,
                open: txn.id == selectedId,
                selecting: selection.active,
                ticked: selection.contains(txn.id),
                onTap: () => onTapRow(txn.id),
                onLongPress: onLongPressRow == null
                    ? null
                    : () => onLongPressRow!(txn.id),
              ),
              const LedgerDivider(),
            ],
          ],
        ],
      ],
    );
  }

  /// The day's income minus its spending; transfers move nothing.
  String? _dayNet(List<TransactionEntity> items) {
    var n = 0.0;
    for (final t in items) {
      final v = t.amount.toInrMoney().amount.toDouble();
      if (t.type == TxnType.income) n += v;
      if (t.type == TxnType.expense) n -= v;
    }
    return n == 0 ? null : _signed(n);
  }
}

String _signed(double v) =>
    v > 0 ? '+${MoneyFormat.money(v)}' : MoneyFormat.money(v);

/// One transaction as a flat ledger row:
///
///   Food & Dining · 7:30 pm · UPI
///   Groceries                               -₹200.00
///   [Pending]
class _TxnRow extends ConsumerWidget {
  const _TxnRow({
    required this.txn,
    required this.open,
    required this.selecting,
    required this.ticked,
    required this.onTap,
    required this.onLongPress,
  });

  final TransactionEntity txn;

  /// Shown in the tablet's detail pane.
  final bool open;
  final bool selecting;
  final bool ticked;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = context.finance;
    final money = MoneyFormat.money(
      txn.amount.amount.toDouble().abs(),
      currency: txn.amount.currency,
    );
    final (value, color, said) = switch (txn.type) {
      TxnType.income => (incomeText(ref, '+$money'), finance.income, 'Income'),
      TxnType.expense => ('-$money', finance.expense, 'Expense'),
      TxnType.transfer => (money, finance.transfer, 'Transfer'),
    };
    final meta = [
      ...txnFacts(txn),
      DateTimeField.formatTime(txn.occurredAt).toLowerCase(),
    ].join(' · ');

    return LedgerRow(
      key: ValueKey(txn.id),
      leading: TxnLeading(txn),
      title: txn.title,
      detail: meta,
      value: value,
      valueColor: color,
      valueLabel: '$said $money',
      detailTag: txn.isPending || txn.hasFailedSync
          ? TxnSyncPill(failed: txn.hasFailedSync)
          : null,
      selecting: selecting,
      selected: selecting ? ticked : open,
      onTap: onTap,
      onLongPress: onLongPress,
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
