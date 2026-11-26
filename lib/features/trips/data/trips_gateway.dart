import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/providers/providers.dart';
import '../domain/trip.dart';

/// `trips` — live PostgREST, not cached (online-only, like Net worth). The
/// phone only reads trips and adds items to a trip's `expenses` jsonb; it
/// never touches `transactions`.
abstract interface class TripsGateway {
  /// Newest first (web useTrips).
  Future<List<Trip>> list(String tenantId);

  /// Prepend [expense] to the trip's `expenses` array.
  Future<void> addExpense(String tenantId, String tripId, TripExpense expense);
}

class SupabaseTripsGateway implements TripsGateway {
  SupabaseTripsGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Trip>> list(String tenantId) async {
    try {
      final rows = await _client
          .from('trips')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);
      return [
        for (final r in rows as List)
          Trip.fromRow(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> addExpense(
    String tenantId,
    String tripId,
    TripExpense expense,
  ) async {
    try {
      // Read the array fresh right before writing, so an item the web added
      // a moment ago is kept (the web writes the whole array the same way).
      final row = await _client
          .from('trips')
          .select('expenses')
          .eq('id', tripId)
          .eq('tenant_id', tenantId)
          .single();
      final current = row['expenses'];
      final next = [expense.toJson(), if (current is List) ...current];
      await _client
          .from('trips')
          .update({'expenses': next})
          .eq('id', tripId)
          .eq('tenant_id', tenantId);
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

final tripsGatewayProvider = Provider<TripsGateway>(
  (ref) => SupabaseTripsGateway(ref.watch(supabaseClientProvider)),
  name: 'tripsGateway',
);
