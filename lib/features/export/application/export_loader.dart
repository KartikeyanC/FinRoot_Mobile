import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show ClientException;

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../../data/local/sync_enums.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/ledger_range.dart';
import '../../transactions/domain/transaction.dart';
import '../data/export_transactions_source.dart';

/// The rows an export will write, and whether they are only the phone's copy.
class ExportRows {
  const ExportRows(this.rows, {this.phoneOnly = false});

  /// Oldest first.
  final List<TransactionEntity> rows;

  /// True when the range reaches past the cache but the server couldn't be
  /// reached, so the file holds only what the phone has (~180 days).
  final bool phoneOnly;
}

/// Picks where an export reads from. A range the cache fully covers reads the
/// cache (instant, offline). A range older than the cache ("All time", "This
/// year" late in the year) reads the server, paged; offline, it falls back to
/// the cache and says so.
class ExportLoader {
  ExportLoader({
    required this.cache,
    required this.server,
    required this.isOnline,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final TransactionsRepository cache;
  final ServerExportSource server;
  final bool Function() isOnline;
  final DateTime Function() _now;

  Future<ExportRows> load(
    String tenantId, {
    required DateTime from,
    required DateTime toExclusive,
  }) async {
    final local = await cache
        .watchBetween(tenantId, from: from, toExclusive: toExclusive)
        .first;
    if (!startsBeforeCache(from, _now())) return ExportRows(local);
    if (!isOnline()) return ExportRows(local, phoneOnly: true);

    final deleted = await cache.pendingDeleteIds(tenantId);
    final List<TransactionEntity> remote;
    try {
      remote = await server.fetchBetween(
        tenantId,
        from: from,
        toExclusive: toExclusive,
      );
    } on NetworkFailure {
      return ExportRows(local, phoneOnly: true);
    } on Failure catch (f) {
      // A dropped connection from the http client surfaces unclassified.
      if (f.cause is ClientException) return ExportRows(local, phoneOnly: true);
      rethrow;
    }

    // The server is the truth, except for edits this phone hasn't sent yet —
    // including deletes, which the server still has.
    final byId = {for (final t in remote) t.id: t};
    for (final t in local) {
      if (t.syncState != LocalSyncStatus.synced) byId[t.id] = t;
    }
    byId.removeWhere((id, _) => deleted.contains(id));
    final merged = byId.values.toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return ExportRows(merged);
  }
}

final exportLoaderProvider = Provider<ExportLoader>(
  (ref) => ExportLoader(
    cache: ref.watch(transactionsRepositoryProvider),
    server: ref.watch(serverExportSourceProvider),
    isOnline: () => ref.read(isOnlineProvider),
  ),
  name: 'exportLoader',
);
