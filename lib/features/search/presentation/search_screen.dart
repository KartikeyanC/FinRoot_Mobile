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
    final palette = context.palette;

    final field = Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadius.chip,
        border: Border.all(color: palette.line),
      ),
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: palette.muted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _box,
              autofocus: true,
              onChanged: (v) {
                setState(() {});
                _changed(v);
              },
              textInputAction: TextInputAction.search,
              style: AppTypography.body.copyWith(color: palette.ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search notes, categories, accounts…',
                hintStyle: AppTypography.body.copyWith(color: palette.faint, fontSize: 15),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_box.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: Icon(Icons.close_rounded, color: palette.muted),
              onPressed: () {
                _box.clear();
                _changed('');
                setState(() {});
              },
            ),
        ],
      ),
    );

    return AppPage(
      title: 'Search',
      header: field,
      padBody: false,
      body: q.isEmpty
          ? const _Hint(
              icon: Icons.search_rounded,
              title: 'Search your workspace',
              message: 'Type to search transactions, accounts, trackers and goals.',
            )
          : none
              ? _Hint(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Nothing matches "$q". Try another word.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    0,
                    AppSpacing.screenGutter,
                    AppSpacing.huge,
                  ),
                  children: [
                    if (accounts.isNotEmpty) ...[
                      _Heading('Accounts', accounts.length),
                      for (final a in accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListRow(
                            icon: Icons.account_balance_wallet_outlined,
                            title: a.name,
                            subtitle: a.typeLabel,
                            chevron: true,
                            onTap: () => context.push('/accounts'),
                          ),
                        ),
                    ],
                    if (trackers.isNotEmpty) ...[
                      _Heading('Trackers', trackers.length),
                      for (final t in trackers)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListRow(
                            icon: Icons.track_changes_outlined,
                            title: t.name,
                            subtitle: t.status == 'active' ? t.type : '${t.type} · ${t.status}',
                            chevron: true,
                            onTap: () => context.push('/tracker/${t.id}'),
                          ),
                        ),
                    ],
                    if (goals.isNotEmpty) ...[
                      _Heading('Goals', goals.length),
                      for (final g in goals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: ListRow(
                            icon: Icons.flag_outlined,
                            title: g.title,
                            subtitle: g.category,
                            chevron: true,
                            onTap: () => context.push('/goals'),
                          ),
                        ),
                    ],
                    if (txns.isNotEmpty) ...[
                      _Heading('Transactions', txns.length, more: txns.length >= 50),
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          children: [
                            for (var i = 0; i < txns.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: palette.line),
                              TransactionTile(
                                txns[i],
                                onTap: () => openTransactionDetail(context, txns[i].id),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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
  Widget build(BuildContext context) => SectionTitle(
        label,
        trailing: StatusPill(
          more ? 'latest $count' : '$count',
          background: context.palette.tint,
          foreground: context.palette.accentText,
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      EmptyView(icon: icon, title: title, message: message);
}
