import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/kv_cache_store.dart';
import '../../sync/application/sync_engine.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/tracker_gateways.dart';
import '../data/trackers_repository.dart';
import '../domain/tracker.dart';
import '../domain/tracker_spend.dart';

/// Which lifecycle states the Trackers list shows. Defaults to active only.
class TrackerStatusFilter extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {'active'};

  void toggle(String status) {
    final next = {...state};
    next.contains(status) ? next.remove(status) : next.add(status);
    state = next.isEmpty ? const {'active'} : next;
  }

  void only(Set<String> statuses) => state = statuses;
}

final trackerStatusFilterProvider =
    NotifierProvider<TrackerStatusFilter, Set<String>>(
      TrackerStatusFilter.new,
      name: 'trackerStatusFilter',
    );

/// Trackers for the active workspace, filtered by [trackerStatusFilterProvider].
final trackersListProvider = StreamProvider<List<TrackerEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <TrackerEntity>[]);
  final statuses = ref.watch(trackerStatusFilterProvider);
  return ref.watch(trackersRepositoryProvider).watchAll(
    tenantId,
    statuses: statuses,
  );
}, name: 'trackersList');

final trackerByIdProvider = StreamProvider.family<TrackerEntity?, String>((
  ref,
  id,
) {
  return ref.watch(trackersRepositoryProvider).watchById(id);
}, name: 'trackerById');

const _kTrackerSpendKey = 'tracker_spend';

/// `tracker_spend()` rows — server-derived (ADR-0006). Online: fetched and
/// cached to `kv_cache`; offline / error: the last cached copy. Refetches when
/// a sync completes or a tracker / assignment write invalidates it.
final trackerSpendRowsProvider = FutureProvider<List<TrackerSpendRow>>((
  ref,
) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];

  ref.watch(syncEngineProvider.select((s) => s.lastSyncedAt));
  final store = ref.watch(kvCacheStoreProvider);

  if (ref.watch(isOnlineProvider)) {
    try {
      final rows = await ref.watch(trackerSpendGatewayProvider).fetch(tenantId);
      await store.write(
        tenantId,
        _kTrackerSpendKey,
        jsonEncode([
          for (final r in rows)
            {
              'tracker_id': r.trackerId,
              'type': r.type,
              'currency': r.currency,
              'total': r.total.toString(),
              'count': r.count,
            },
        ]),
      );
      return rows;
    } on Failure {
      // fall through to cache
    }
  }

  final cached = await store.read(tenantId, _kTrackerSpendKey);
  if (cached != null) {
    return [
      for (final r in jsonDecode(cached) as List<dynamic>)
        TrackerSpendRow.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }
  return const [];
}, name: 'trackerSpendRows');

/// The list, with spend folded on.
final trackersWithSpendProvider = Provider<AsyncValue<List<TrackerWithSpend>>>((
  ref,
) {
  final trackers = ref.watch(trackersListProvider);
  final rows = ref.watch(trackerSpendRowsProvider).value;
  return trackers.whenData((list) => foldTrackerSpend(list, rows));
}, name: 'trackersWithSpend');

/// One tracker with spend, for the detail screen. Falls back to a
/// spend-less fold while the roll-up loads.
final trackerWithSpendProvider = Provider.family<TrackerWithSpend?, String>((
  ref,
  id,
) {
  final tracker = ref.watch(trackerByIdProvider(id)).value;
  if (tracker == null) return null;
  final rows = ref.watch(trackerSpendRowsProvider).value;
  return foldTrackerSpend([tracker], rows).first;
}, name: 'trackerWithSpend');

/// The transactions tagged to one tracker (from the cache — the same rows as
/// everywhere else; nothing is duplicated).
final trackerTransactionsProvider =
    StreamProvider.family<List<TransactionEntity>, String>((ref, trackerId) {
      final tenantId = ref.watch(currentTenantIdProvider);
      if (tenantId == null) {
        return Stream.value(const <TransactionEntity>[]);
      }
      return ref
          .watch(transactionsRepositoryProvider)
          .watchLedger(tenantId, trackerId: trackerId);
    }, name: 'trackerTransactions');

/// Untagged transactions inside a tracker's date window — the pool the
/// "assign older transactions" flow offers.
final untaggedForTrackerProvider =
    StreamProvider.family<List<TransactionEntity>, String>((ref, trackerId) {
      final tenantId = ref.watch(currentTenantIdProvider);
      final tracker = ref.watch(trackerByIdProvider(trackerId)).value;
      if (tenantId == null || tracker == null) {
        return Stream.value(const <TransactionEntity>[]);
      }
      final from = DateTime.utc(
        tracker.startDate.year,
        tracker.startDate.month,
        tracker.startDate.day,
      );
      final end = tracker.endDate;
      final toExclusive = end == null
          ? null
          : DateTime.utc(
              end.year,
              end.month,
              end.day,
            ).add(const Duration(days: 1));
      return ref
          .watch(transactionsRepositoryProvider)
          .watchUntaggedInWindow(
            tenantId,
            from: from,
            toExclusive: toExclusive,
          );
    }, name: 'untaggedForTracker');
