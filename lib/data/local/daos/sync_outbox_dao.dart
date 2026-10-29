import 'dart:convert';

import 'package:drift/drift.dart';

import '../app_database.dart';

part 'sync_outbox_dao.g.dart';

/// The offline mutation queue. The sync engine (M5) drains it; M4 defines and
/// exercises the store only.
///
/// Lifecycle of an entry: `pending` → (worker picks it up) `inFlight` →
///   • success → the row is **deleted** (the mutation is now recorded
///     server-side in `client_mutations`; a local copy would only drift), or
///   • a retryable failure → back to `pending` for the next run, or
///   • a permanent failure (validation / permission) → `failed`, needs the
///     user.
@DriftAccessor(tables: [SyncOutbox])
class SyncOutboxDao extends DatabaseAccessor<AppDatabase>
    with _$SyncOutboxDaoMixin {
  SyncOutboxDao(super.db);

  /// Queue a mutation. [mutationId] is the client UUID that will be sent to
  /// `apply_transaction_mutation` on every retry (M1.5) — generate it once, at
  /// the call site, and store it on the affected cache row too.
  Future<void> enqueue({
    required String mutationId,
    required String tenantId,
    required OutboxOperation operation,
    required String entityLocalId,
    Map<String, dynamic>? payload,
    String entity = 'transaction',
  }) {
    return into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        mutationId: mutationId,
        tenantId: tenantId,
        operation: operation,
        entityLocalId: entityLocalId,
        entity: Value(entity),
        payload: Value(payload == null ? null : jsonEncode(payload)),
      ),
    );
  }

  /// How long an entry may sit "in flight" before it counts as abandoned.
  /// An app (or the floating Quick Log window) closed mid-send leaves its
  /// entry in flight; without this it was never sent again.
  static const staleInFlight = Duration(minutes: 2);

  /// Oldest-first batch of entries ready to send: pending ones, plus any left
  /// in flight by a send that never finished. Resending is safe — creates
  /// carry the phone's own id, so a repeat is recognised as already applied.
  Future<List<OutboxEntry>> pendingBatch({int limit = 50, DateTime? now}) {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(staleInFlight);
    return (select(syncOutbox)
          ..where(
            (t) =>
                t.status.equalsValue(OutboxStatus.pending) |
                (t.status.equalsValue(OutboxStatus.inFlight) &
                    (t.lastAttemptAt.isNull() |
                        t.lastAttemptAt.isSmallerThanValue(cutoff))),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Entries the server refused, oldest first — for the "didn't sync" details.
  Stream<List<OutboxEntry>> watchFailed() {
    return (select(syncOutbox)
          ..where((t) => t.status.equalsValue(OutboxStatus.failed))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Drop one entry without sending it (the person chose "Discard").
  Future<void> discard(int id) {
    return (delete(syncOutbox)..where((t) => t.id.equals(id))).go();
  }

  Future<OutboxEntry?> byMutationId(String mutationId) {
    return (select(
      syncOutbox,
    )..where((t) => t.mutationId.equals(mutationId))).getSingleOrNull();
  }

  Future<int> countPending() => _countWithStatus(OutboxStatus.pending);
  Future<int> countFailed() => _countWithStatus(OutboxStatus.failed);

  Future<int> _countWithStatus(OutboxStatus status) async {
    final rows =
        await (selectOnly(syncOutbox)
              ..addColumns([syncOutbox.id.count()])
              ..where(syncOutbox.status.equalsValue(status)))
            .get();
    return rows.first.read(syncOutbox.id.count()) ?? 0;
  }

  /// Live count of entries not yet confirmed by the server (pending + failed).
  Stream<int> watchUnsyncedCount() {
    final q = selectOnly(syncOutbox)
      ..addColumns([syncOutbox.id.count()])
      ..where(syncOutbox.status.equalsValue(OutboxStatus.inFlight).not());
    return q.map((r) => r.read(syncOutbox.id.count()) ?? 0).watchSingle();
  }

  /// Mark an entry as being sent now and count the attempt.
  Future<void> markInFlight(int id) {
    return customUpdate(
      'UPDATE sync_outbox SET status = ?, attempts = attempts + 1, '
      'last_attempt_at = ? WHERE id = ?',
      variables: [
        Variable<String>(OutboxStatus.inFlight.name),
        Variable<DateTime>(DateTime.now().toUtc()),
        Variable<int>(id),
      ],
      updates: {syncOutbox},
    );
  }

  /// The server accepted it (applied or replayed) — the entry is done.
  Future<void> markSynced(int id) {
    return (delete(syncOutbox)..where((t) => t.id.equals(id))).go();
  }

  /// A retryable failure — hand it back to the queue for the next run.
  Future<void> markRetry(int id, String error) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(OutboxStatus.pending),
        lastError: Value(_short(error)),
      ),
    );
  }

  /// A permanent failure — validation, permission, a reused id. Needs the user.
  Future<void> markFailed(int id, String error) {
    return (update(syncOutbox)..where((t) => t.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value(OutboxStatus.failed),
        lastError: Value(_short(error)),
      ),
    );
  }

  /// Put failed entries back in the queue with a fresh attempt count (the old
  /// count made a retried entry fail again at once). With [olderThan], only
  /// entries last tried before then — the sync engine's periodic self-heal,
  /// so a problem fixed on the server clears without anyone tapping Retry.
  Future<int> requeueFailed({DateTime? olderThan}) {
    final q = update(syncOutbox)
      ..where((t) {
        final failed = t.status.equalsValue(OutboxStatus.failed);
        if (olderThan == null) return failed;
        return failed &
            (t.lastAttemptAt.isNull() |
                t.lastAttemptAt.isSmallerThanValue(olderThan.toUtc()));
      });
    return q.write(
      const SyncOutboxCompanion(
        status: Value(OutboxStatus.pending),
        attempts: Value(0),
      ),
    );
  }

  Future<void> clearForTenant(String tenantId) {
    return (delete(syncOutbox)..where((t) => t.tenantId.equals(tenantId))).go();
  }

  static String _short(String s) => s.length > 300 ? s.substring(0, 300) : s;
}
