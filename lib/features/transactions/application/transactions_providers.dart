import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/constants.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/transactions_repository.dart';
import '../domain/ledger_range.dart';
import '../domain/transaction.dart';

/// What the Transactions ledger is currently showing.
class LedgerFilter {
  const LedgerFilter({
    this.type,
    this.search = '',
    this.accountId,
    this.range,
    this.categories = const {},
  });

  /// null = all types.
  final TxnType? type;
  final String search;

  /// Set when the ledger was opened from an account (M8 accounts → ledger).
  final String? accountId;

  /// null = any date.
  final LedgerRange? range;

  /// Empty = every category; otherwise rows in any of these.
  final Set<String> categories;

  bool get isActive =>
      type != null ||
      search.trim().isNotEmpty ||
      accountId != null ||
      range != null ||
      categories.isNotEmpty;

  /// The date / category part is set (what the chip row shows and Clear resets).
  bool get hasRangeOrCategory => range != null || categories.isNotEmpty;

  LedgerFilter copyWith({
    Object? type = _keep,
    String? search,
    Object? accountId = _keep,
    Object? range = _keep,
    Set<String>? categories,
  }) {
    return LedgerFilter(
      type: type == _keep ? this.type : type as TxnType?,
      search: search ?? this.search,
      accountId: accountId == _keep ? this.accountId : accountId as String?,
      range: range == _keep ? this.range : range as LedgerRange?,
      categories: categories ?? this.categories,
    );
  }

  static const _keep = Object();
}

class LedgerFilterNotifier extends Notifier<LedgerFilter> {
  @override
  LedgerFilter build() => const LedgerFilter();

  void setType(TxnType? type) => state = state.copyWith(type: type);
  void setSearch(String search) => state = state.copyWith(search: search);
  void setAccount(String? accountId) =>
      state = state.copyWith(accountId: accountId);
  void setRange(LedgerRange? range) => state = state.copyWith(range: range);
  void setCategories(Set<String> categories) =>
      state = state.copyWith(categories: Set.unmodifiable(categories));
  void removeCategory(String category) => state = state.copyWith(
    categories: Set.unmodifiable({...state.categories}..remove(category)),
  );
  void clear() => state = const LedgerFilter();
}

final ledgerFilterProvider =
    NotifierProvider<LedgerFilterNotifier, LedgerFilter>(
      LedgerFilterNotifier.new,
      name: 'ledgerFilter',
    );

/// The filtered ledger, live from the cache.
final ledgerProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <TransactionEntity>[]);
  final f = ref.watch(ledgerFilterProvider);
  return ref
      .watch(transactionsRepositoryProvider)
      .watchLedger(
        tenantId,
        type: f.type,
        search: f.search,
        accountId: f.accountId,
        from: f.range?.from,
        toExclusive: f.range?.toExclusive,
        categories: f.categories,
      );
}, name: 'ledger');

/// Every category the cache holds, for the ledger's category filter.
final ledgerCategoriesProvider = StreamProvider<List<String>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <String>[]);
  return ref.watch(transactionsRepositoryProvider).watchCategories(tenantId);
}, name: 'ledgerCategories');

final transactionByIdProvider =
    StreamProvider.family<TransactionEntity?, String>((ref, id) {
      return ref.watch(transactionsRepositoryProvider).watchById(id);
    }, name: 'transactionById');
