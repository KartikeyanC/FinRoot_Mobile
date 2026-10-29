import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/price_alert.dart';

/// The workspace's price alerts, in `tenant_settings` under `price_alerts` —
/// the same row the web dashboard reads and writes (`src/lib/tenantSettings.ts`
/// registers the key). RLS: any member reads, an admin or owner writes.
abstract interface class PriceAlertsGateway {
  Future<List<PriceAlert>> load(String tenantId);
  Future<void> save(String tenantId, String? userId, List<PriceAlert> alerts);
}

const priceAlertsSettingKey = 'price_alerts';

class SupabasePriceAlertsGateway implements PriceAlertsGateway {
  SupabasePriceAlertsGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<PriceAlert>> load(String tenantId) async {
    try {
      final row = await _client
          .from('tenant_settings')
          .select('value')
          .eq('tenant_id', tenantId)
          .eq('key', priceAlertsSettingKey)
          .maybeSingle();
      return parseStoredAlerts(row?['value']);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> save(
    String tenantId,
    String? userId,
    List<PriceAlert> alerts,
  ) async {
    try {
      await _client.from('tenant_settings').upsert({
        'tenant_id': tenantId,
        'key': priceAlertsSettingKey,
        'value': [for (final a in alerts) a.toJson()],
        'updated_by': userId,
      }, onConflict: 'tenant_id,key');
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final priceAlertsGatewayProvider = Provider<PriceAlertsGateway>(
  (ref) => SupabasePriceAlertsGateway(ref.watch(supabaseClientProvider)),
  name: 'priceAlertsGateway',
);
