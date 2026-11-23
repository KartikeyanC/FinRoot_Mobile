import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/import_rows.dart';

/// How an import went: rows written, and rows the database already had.
class ImportOutcome {
  const ImportOutcome({required this.inserted, required this.attempted});
  final int inserted;
  final int attempted;
  int get skipped => attempted - inserted;
}

/// Writes imported rows exactly as the web does
/// (`src/hooks/useImportTransactions.ts`): one upsert on
/// `(tenant_id, import_hash)` with duplicates ignored, so a statement
/// imported twice — on either device — is stored once.
abstract class ImportGateway {
  Future<ImportOutcome> importRows({
    required String tenantId,
    required String userId,
    required List<ImportRow> rows,
  });
}

class SupabaseImportGateway implements ImportGateway {
  SupabaseImportGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<ImportOutcome> importRows({
    required String tenantId,
    required String userId,
    required List<ImportRow> rows,
  }) async {
    if (rows.isEmpty) return const ImportOutcome(inserted: 0, attempted: 0);
    final payload = [
      for (final r in rows)
        {
          'user_id': userId,
          'tenant_id': tenantId,
          'type': r.type,
          'amount': r.amount.toStringAsFixed(2),
          'currency': r.currency,
          'category': r.category,
          'description': r.description.isEmpty ? null : r.description,
          'occurred_at': r.occurredAt,
          'import_hash': r.importHash,
        },
    ];
    try {
      final written = await _client
          .from('transactions')
          .upsert(
            payload,
            onConflict: 'tenant_id,import_hash',
            ignoreDuplicates: true,
          )
          .select('id');
      return ImportOutcome(inserted: written.length, attempted: rows.length);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final importGatewayProvider = Provider<ImportGateway>(
  (ref) => SupabaseImportGateway(ref.watch(supabaseClientProvider)),
  name: 'importGateway',
);
