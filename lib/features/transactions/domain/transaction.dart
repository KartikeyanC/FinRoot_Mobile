import '../../../core/money/money.dart';
import '../../../data/local/sync_enums.dart';
import '../../../domain/constants.dart';

/// A transaction as the UI needs it — a plain value type, no Drift, no money
/// maths. The amount is exactly what the server (or the offline capture) set;
/// nothing here re-derives it (ADR-0006).
class TransactionEntity {
  const TransactionEntity({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.occurredAt,
    this.description,
    this.trackerId,
    this.accountId,
    this.transferToAccountId,
    this.paymentMode,
    this.syncState = LocalSyncStatus.synced,
  });

  final String id;
  final TxnType type;
  final Money amount;
  final String category;
  final DateTime occurredAt;
  final String? description;
  final String? trackerId;

  /// Paying account (any type); for a transfer this is the SOURCE.
  final String? accountId;

  /// Destination account — set only for a transfer.
  final String? transferToAccountId;
  final String? paymentMode;

  /// Where this row stands relative to the server — drives the pending / failed
  /// affordance on the row (M6 surfaces it; M7 creates the pending rows).
  final LocalSyncStatus syncState;

  bool get isPending =>
      syncState == LocalSyncStatus.pendingCreate ||
      syncState == LocalSyncStatus.pendingUpdate ||
      syncState == LocalSyncStatus.pendingDelete;

  bool get hasFailedSync => syncState == LocalSyncStatus.failed;

  /// A one-line label for the row: the note if there is one, otherwise the
  /// category (never a bare id).
  String get title {
    final note = description?.trim();
    return (note == null || note.isEmpty) ? category : note;
  }
}
