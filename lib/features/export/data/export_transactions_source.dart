import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/money/money.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../transactions/domain/transaction.dart';

/// One page of server transaction rows: `occurred_at` in `[from, toExclusive)`
/// for [tenantId], oldest first, rows `offset .. offset + limit - 1`.
typedef TransactionPageFetcher = Future<List<Map<String, dynamic>>> Function({
  required String tenantId,
  required DateTime from,
  required DateTime toExclusive,
  required int offset,
  required int limit,
});

/// Reads transactions for an export straight from Supabase, so a range older
/// than the phone's ~180-day cache is still complete.
class ServerExportSource {
  ServerExportSource(this._fetchPage, {this.pageSize = 1000});

  final TransactionPageFetcher _fetchPage;
  final int pageSize;

  /// Every server transaction in `[from, toExclusive)`, oldest first, paged
  /// [pageSize] rows at a time. Errors come back as a `Failure` (mapError).
  Future<List<TransactionEntity>> fetchBetween(
    String tenantId, {
    required DateTime from,
    required DateTime toExclusive,
  }) async {
    try {
      final out = <TransactionEntity>[];
      for (var offset = 0; ; offset += pageSize) {
        final page = await _fetchPage(
          tenantId: tenantId,
          from: from,
          toExclusive: toExclusive,
          offset: offset,
          limit: pageSize,
        );
        for (final r in page) {
          final t = transactionFromServerRow(r);
          if (t != null) out.add(t);
        }
        if (page.length < pageSize) break;
      }
      return out;
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

/// A PostgREST `transactions` row as an entity; null for a row this app
/// can't read (skipped, like the sync puller does).
TransactionEntity? transactionFromServerRow(Map<String, dynamic> r) {
  try {
    return TransactionEntity(
      id: r['id'] as String,
      type: TxnType.fromWire(r['type'] as String),
      amount: Money(
        Decimal.parse((r['amount'] ?? 0).toString()),
        (r['currency'] as String?) ?? 'INR',
      ),
      category: (r['category'] as String?) ?? 'Other',
      occurredAt: DateTime.parse(r['occurred_at'] as String).toUtc(),
      description: r['description'] as String?,
      trackerId: r['tracker_id'] as String?,
      accountId: r['account_id'] as String?,
      transferToAccountId: r['transfer_to_account_id'] as String?,
      paymentMode: r['payment_mode'] as String?,
    );
  } catch (_) {
    return null;
  }
}

final serverExportSourceProvider = Provider<ServerExportSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ServerExportSource(({
    required tenantId,
    required from,
    required toExclusive,
    required offset,
    required limit,
  }) async {
    final rows = await client
        .from('transactions')
        .select()
        .eq('tenant_id', tenantId)
        .gte('occurred_at', from.toUtc().toIso8601String())
        .lt('occurred_at', toExclusive.toUtc().toIso8601String())
        .order('occurred_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  });
}, name: 'serverExportSource');
