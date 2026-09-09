import 'package:finroot_mobile/data/local/app_database.dart';
import 'package:finroot_mobile/features/sync/data/mutation_gateway.dart';
import 'package:finroot_mobile/features/sync/data/pull_gateway.dart';
import 'package:finroot_mobile/features/sync/domain/sync_types.dart';

/// A scripted [MutationGateway]: returns queued results, or throws queued
/// errors, one per `apply` call.
class FakeMutationGateway implements MutationGateway {
  final List<Object> _script = [];
  final List<OutboxEntry> calls = [];

  void enqueueResult(MutationResult r) => _script.add(r);
  void enqueueError(Object e) => _script.add(e);

  /// Every call returns this (ignores the script) when set.
  Object? always;

  @override
  Future<MutationResult> apply(OutboxEntry entry) async {
    calls.add(entry);
    final item = always ?? (_script.isNotEmpty ? _script.removeAt(0) : null);
    if (item is MutationResult) return item;
    if (item is Object && item is! MutationResult) throw item;
    return const MutationResult(status: 'applied', deleted: false);
  }
}

/// A [PullGateway] backed by in-memory row lists per entity.
class FakePullGateway implements PullGateway {
  final Map<SyncEntity, List<Map<String, dynamic>>> rows = {
    for (final e in SyncEntity.values) e: [],
  };

  @override
  Future<PullPage> fetchSince(
    SyncEntity entity,
    String tenantId, {
    required DateTime? since,
    required int limit,
    DateTime? transactionWindowStart,
  }) async {
    var list = rows[entity]!.where((r) => r['tenant_id'] == tenantId).toList()
      ..sort(
        (a, b) =>
            (a['updated_at'] as String).compareTo(b['updated_at'] as String),
      );
    if (since != null) {
      list = list
          .where(
            (r) => DateTime.parse(r['updated_at'] as String).isAfter(since),
          )
          .toList();
    }
    final page = list.take(limit).toList();
    return PullPage(rows: page, hasMore: page.length >= limit);
  }

  @override
  Future<Set<String>> fetchLiveIds(
    SyncEntity entity,
    String tenantId, {
    DateTime? transactionWindowStart,
  }) async {
    return {
      for (final r in rows[entity]!)
        if (r['tenant_id'] == tenantId) r['id'] as String,
    };
  }
}

/// Minimal server transaction row (snake_case, as PostgREST returns it).
Map<String, dynamic> serverTxn({
  required String id,
  required String tenant,
  String type = 'expense',
  String amount = '100.00',
  String category = 'Other',
  String? tracker,
  required DateTime updatedAt,
  DateTime? occurredAt,
}) {
  return {
    'id': id,
    'tenant_id': tenant,
    'user_id': 'u1',
    'type': type,
    'amount': amount,
    'currency': 'INR',
    'category': category,
    'description': null,
    'occurred_at': (occurredAt ?? updatedAt).toUtc().toIso8601String(),
    'account_id': null,
    'payment_mode': null,
    'transfer_to_account_id': null,
    'tracker_id': tracker,
    'created_at': updatedAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}
