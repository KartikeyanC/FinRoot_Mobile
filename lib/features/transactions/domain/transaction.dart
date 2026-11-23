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

  /// The note as the person typed it, without the markers the web stores in
  /// it (`⟦SPLIT|mode|friend⟧`, `[Account|id]`).
  TxnNote get note => TxnNote.parse(description);

  /// A one-line label for the row: the clean note if there is one, otherwise
  /// the category (never a bare id or an internal marker).
  String get title {
    final n = note.text;
    return n.isEmpty ? category : n;
  }
}

/// A transaction note split into what the person wrote and the markers the
/// web app embeds (see `src/lib/transactionDisplay.ts` / `splitMeta.ts`).
class TxnNote {
  const TxnNote({
    required this.text,
    this.account,
    this.splitMode,
    this.splitFriend,
  });

  final String text;

  /// Account name from an account-linked `[Name|id]` prefix.
  final String? account;

  /// `paid_full`, `settled` or `owe` for a split bill.
  final String? splitMode;
  final String? splitFriend;

  static final _split = RegExp(
    r'^⟦SPLIT\|(paid_full|settled|owe)\|([^⟧]*)⟧\s?',
  );
  static final _account = RegExp(r'^\[([^\]|]+)\|[^\]]+\]\s*');

  static TxnNote parse(String? raw) {
    var s = raw ?? '';
    String? mode, friend, account;
    final m = _split.firstMatch(s);
    if (m != null) {
      mode = m.group(1);
      final f = m.group(2) ?? '';
      friend = f.isEmpty ? 'Friend' : f;
      s = s.substring(m.end);
    }
    final a = _account.firstMatch(s);
    if (a != null) {
      account = a.group(1)!.trim();
      s = s.substring(a.end);
    }
    return TxnNote(
      text: s.trim(),
      account: account,
      splitMode: mode,
      splitFriend: friend,
    );
  }
}
