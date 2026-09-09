import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/constants.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction.dart';

/// What the Transactions ledger is currently showing.
class LedgerFilter {
  const LedgerFilter({this.type, this.search = '', this.accountId});

  /// null = all types.
  final TxnType? type;
  final String search;

  /// Set when the ledger was opened from an account (M8 accounts → ledger).
  final String? accountId;

  bool get isActive =>
      type != null || search.trim().isNotEmpty || accountId != null;

  LedgerFilter copyWith({
    Object? type = _keep,
    String? search,
    Object? accountId = _keep,
  }) {
    return LedgerFilter(
      type: type == _keep ? this.type : type as TxnType?,
      search: search ?? this.search,
      accountId: accountId == _keep ? this.accountId : accountId as String?,
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
      );
}, name: 'ledger');

final transactionByIdProvider =
    StreamProvider.family<TransactionEntity?, String>((ref, id) {
      return ref.watch(transactionsRepositoryProvider).watchById(id);
    }, name: 'transactionById');
