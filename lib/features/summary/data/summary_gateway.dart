import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/workspace_summary.dart';

/// Fetches the `dashboard_summary` roll-up. Abstract so the providers can be
/// tested without Supabase.
abstract interface class SummaryGateway {
  Future<WorkspaceSummary> fetch(String tenantId, {int months = 6});
}

class SupabaseSummaryGateway implements SummaryGateway {
  SupabaseSummaryGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<WorkspaceSummary> fetch(String tenantId, {int months = 6}) async {
    try {
      final res = await _client.rpc<dynamic>(
        'dashboard_summary',
        params: {
          'p_tenant_id': tenantId,
          'p_months': months,
          // Flutter has no IANA zone name without a plugin, and Postgres
          // `AT TIME ZONE` rejects the platform's display name. UTC keeps the
          // month buckets well-defined; only transactions within a few hours
          // of a month boundary can land in the neighbouring bucket, which is
          // acceptable for the current-month figure on Home (I-31).
          'p_tz': 'UTC',
        },
      );
      final map = res is Map
          ? Map<String, dynamic>.from(res)
          : <String, dynamic>{};
      return WorkspaceSummary.fromRpc(map);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final summaryGatewayProvider = Provider<SummaryGateway>(
  (ref) => SupabaseSummaryGateway(ref.watch(supabaseClientProvider)),
  name: 'summaryGateway',
);
