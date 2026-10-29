import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../goals/application/goals_providers.dart';
import '../../goals/domain/goal.dart';
import '../../trackers/data/trackers_repository.dart';
import '../../trackers/domain/tracker.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../transactions/presentation/transaction_detail_sheet.dart';
import '../../transactions/presentation/widgets/transaction_tile.dart';
import '../../workspace/application/workspace_providers.dart';

/// True when [text] contains [query], ignoring case.
bool matchesQuery(String? text, String query) =>
    text != null && text.toLowerCase().contains(query.trim().toLowerCase());

/// Transactions whose note or category contains the query (the ledger's own
/// search), from the local cache, so it works offline.
final searchTransactionsProvider =
    StreamProvider.autoDispose.family<List<TransactionEntity>, String>((ref, q) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null || q.trim().isEmpty) return Stream.value(const []);
  return ref.watch(transactionsRepositoryProvider).watchLedger(tenantId, search: q, limit: 50);
}, name: 'searchTransactions');

/// Every tracker, whatever its status (the Trackers tab filters by status).
final searchTrackersProvider = StreamProvider.autoDispose<List<TrackerEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const []);
  return ref.watch(trackersRepositoryProvider).watchAll(
    tenantId,
    statuses: const {'active', 'completed', 'archived'},
  );
}, name: 'searchTrackers');

/// One search box over the whole workspace: transactions, accounts, trackers
/// and goals. Everything comes from the phone's cache.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _box = TextEditingController();
  Timer? _debounce;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _box.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query;
    final accounts = [
      for (final a in ref.watch(workspaceAccountsProvider).value ?? const <AccountEntity>[])
        if (q.isNotEmpty && (matchesQuery(a.name, q) || matchesQuery(a.typeLabel, q))) a,
    ];
    final trackers = [
      for (final t in ref.watch(searchTrackersProvider).value ?? const <TrackerEntity>[])
        if (q.isNotEmpty && (matchesQuery(t.name, q) || matchesQuery(t.description, q))) t,
    ];
    final goals = [
      for (final g in ref.watch(goalsProvider).value ?? const <GoalEntity>[])
        if (q.isNotEmpty && (matchesQuery(g.title, q) || matchesQuery(g.category, q))) g,
    ];
    final txns = ref.watch(searchTransactionsProvider(q)).value ?? const <TransactionEntity>[];
    final none = accounts.isEmpty && trackers.isEmpty && goals.isEmpty && txns.isEmpty;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _box,
          autofocus: true,
          onChanged: _changed,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search notes, categories, accounts…',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_box.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _box.clear();
                _changed('');
              },
            ),
        ],
      ),
      body: q.isEmpty
          ? const _Hint('Type to search transactions, accounts, trackers and goals.')
          : none
              ? _Hint('Nothing matches "$q".')
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenGutter),
                  children: [
                    if (accounts.isNotEmpty) ...[
                      _Heading('Accounts', accounts.length),
                      for (final a in accounts)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.account_balance_wallet_outlined),
                          title: Text(a.name),
                          subtitle: Text(a.typeLabel),
                          onTap: () => context.push('/accounts'),
                        ),
                    ],
                    if (trackers.isNotEmpty) ...[
                      _Heading('Trackers', trackers.length),
                      for (final t in trackers)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.track_changes_outlined),
                          title: Text(t.name),
                          subtitle: Text(t.status == 'active' ? t.type : '${t.type} · ${t.status}'),
                          onTap: () => context.push('/tracker/${t.id}'),
                        ),
                    ],
                    if (goals.isNotEmpty) ...[
                      _Heading('Goals', goals.length),
                      for (final g in goals)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined),
                          title: Text(g.title),
                          subtitle: g.category == null ? null : Text(g.category!),
                          onTap: () => context.push('/goals'),
                        ),
                    ],
                    if (txns.isNotEmpty) ...[
                      _Heading('Transactions', txns.length, more: txns.length >= 50),
                      for (final t in txns)
                        TransactionTile(t, onTap: () => openTransactionDetail(context, t.id)),
                    ],
                    SizedBox(height: tt.bodyMedium?.fontSize ?? AppSpacing.lg),
                  ],
                ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label, this.count, {this.more = false});
  final String label;
  final int count;
  final bool more;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs),
        child: Text(
          '$label · ${more ? 'latest $count' : count}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
