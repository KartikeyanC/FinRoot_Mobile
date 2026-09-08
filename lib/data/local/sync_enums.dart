/// How a cached row stands relative to the server.
enum LocalSyncStatus {
  /// Matches the server (or was pulled from it).
  synced,

  /// Created on device, not yet accepted by the server.
  pendingCreate,

  /// Edited on device, the edit not yet accepted.
  pendingUpdate,

  /// Deleted on device, the delete not yet accepted. The row is kept (hidden)
  /// until the server confirms, so a failed sync can be retried.
  pendingDelete,

  /// A sync attempt failed in a way that will not fix itself (validation,
  /// permission). Needs the user's attention.
  failed,
}

/// State of an outbox entry.
enum OutboxStatus { pending, inFlight, failed }

/// The mutation an outbox entry represents. `wire` is what
/// `apply_transaction_mutation` expects in its `operation` field
/// (backend/M1.5_CLIENT_CONTRACT.md).
enum OutboxOperation {
  createTransaction('create_transaction'),
  updateTransaction('update_transaction'),
  deleteTransaction('delete_transaction');

  const OutboxOperation(this.wire);
  final String wire;
}
