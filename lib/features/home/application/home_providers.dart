import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trackers/data/trackers_repository.dart';
import '../../trackers/domain/tracker.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../workspace/application/workspace_providers.dart';

/// The Home feed's reads. Each is scoped to the active workspace and backed by
/// the local cache (M4), so the feed paints instantly and works offline; the
/// sync engine (M5) keeps the underlying rows fresh.

/// Most recent transactions for the feed's "Recent activity" section.
final recentTransactionsProvider =
    StreamProvider<List<TransactionEntity>>((ref) {
      final tenantId = ref.watch(currentTenantIdProvider);
      if (tenantId == null) {
        return Stream.value(const <TransactionEntity>[]);
      }
      return ref
          .watch(transactionsRepositoryProvider)
          .watchRecent(tenantId);
    }, name: 'recentTransactions');

/// How many transactions the cache holds for the last 30 days — a count of
/// records for the snapshot card, never a sum of money (ADR-0006).
final recentActivityCountProvider = StreamProvider<int>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(0);
  final since = DateTime.now().subtract(const Duration(days: 30));
  return ref
      .watch(transactionsRepositoryProvider)
      .watchCountSince(tenantId, since);
}, name: 'recentActivityCount');

/// Active trackers for the feed's trackers section (menu-gated at the widget).
final activeTrackersProvider = StreamProvider<List<TrackerEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <TrackerEntity>[]);
  return ref.watch(trackersRepositoryProvider).watchActive(tenantId);
}, name: 'activeTrackers');
