import '../../../data/local/sync_enums.dart';

/// The entities the sync engine mirrors. Order matters for a full sync —
/// accounts/trackers before transactions so a freshly pulled transaction's
/// account and tracker are already in the cache.
enum SyncEntity {
  account('account', 'accounts', 'local_accounts'),
  tracker('tracker', 'trackers', 'local_trackers'),
  budget('budget', 'budgets', 'local_budgets'),
  goal('goal', 'goals', 'local_goals'),
  transaction('transaction', 'transactions', 'local_transactions');

  const SyncEntity(this.key, this.table, this.localTable);

  /// The `<entity>:<tenant>` prefix in `sync_states`.
  final String key;

  /// The Supabase table it pulls from.
  final String table;

  /// The Drift cache table it reconciles into.
  final String localTable;
}

/// What a mutation attempt did, from `apply_transaction_mutation`.
class MutationResult {
  const MutationResult({
    required this.status,
    required this.deleted,
    this.transaction,
  });

  /// `applied` (we did it now) or `replayed` (a lost-response retry — the first
  /// attempt had succeeded). The engine treats both the same.
  final String status;
  final bool deleted;

  /// The canonical row, or null for a delete / a create whose row was later
  /// removed server-side.
  final Map<String, dynamic>? transaction;

  bool get isReplayed => status == 'replayed';

  factory MutationResult.fromRpc(Map<String, dynamic> json) => MutationResult(
    status: json['status'] as String? ?? 'applied',
    deleted: json['deleted'] as bool? ?? false,
    transaction: json['transaction'] as Map<String, dynamic>?,
  );
}

/// One page of a delta pull.
class PullPage {
  const PullPage({required this.rows, required this.hasMore});

  /// Server rows, ascending by `updated_at`.
  final List<Map<String, dynamic>> rows;

  /// True when the page filled the limit — call again with the new cursor.
  final bool hasMore;
}

enum SyncPhase { idle, pushing, pulling, done, failed, offline }

/// A snapshot of the engine, watched by the UI (an offline banner, a pending
/// badge, a "last synced" line).
class SyncSnapshot {
  const SyncSnapshot({
    this.phase = SyncPhase.idle,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncPhase phase;
  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get isBusy => phase == SyncPhase.pushing || phase == SyncPhase.pulling;
  bool get hasTrouble => phase == SyncPhase.failed || failedCount > 0;

  SyncSnapshot copyWith({
    SyncPhase? phase,
    int? pendingCount,
    int? failedCount,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncSnapshot(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

extension OutboxOperationX on OutboxOperation {
  bool get isDelete => this == OutboxOperation.deleteTransaction;
  bool get isCreate => this == OutboxOperation.createTransaction;
}
