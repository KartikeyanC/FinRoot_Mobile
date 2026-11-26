import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../domain/trip.dart';

/// `trips` — live PostgREST, not cached (online-only, like Net worth). The
/// phone reads trips, creates them, and adds, edits or removes items of a
/// trip's `expenses` jsonb; it never touches `transactions`.
abstract interface class TripsGateway {
  /// Newest first (web useTrips).
  Future<List<Trip>> list(String tenantId);

  /// Insert a new trip; returns its id.
  Future<String> create(String tenantId, NewTrip trip);

  /// Add, edit or remove one item of the trip's `expenses` array.
  Future<void> changeExpense(
    String tenantId,
    String tripId,
    TripExpenseChange change,
  );
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
      throw _map(error, stack);
    }
  }

  @override
  Future<String> create(String tenantId, NewTrip trip) async {
    final problem = trip.problem;
    if (problem != null) throw ValidationFailure(problem);
    try {
      final row = await _client
          .from('trips')
          .insert(trip.toRow(tenantId))
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (e, stack) {
      if (isTripCurrencyMissing(code: e.code, message: e.message)) {
        throw ValidationFailure(kTripCurrencyMissingMessage, cause: e);
      }
      throw _map(e, stack);
    } catch (error, stack) {
      throw _map(error, stack);
    }
  }

  /// Through the locked trip_expense_* RPC, so two people logging at once
  /// never overwrite each other. Before migration 20261126150000 runs, falls
  /// back to reading the array fresh and writing it whole, by the same rules.
  @override
  Future<void> changeExpense(
    String tenantId,
    String tripId,
    TripExpenseChange change,
  ) async {
    final call = tripExpenseRpcCall(tripId, change);
    try {
      await _client.rpc<dynamic>(call.fn, params: call.params);
      return;
    } on PostgrestException catch (e, stack) {
      if (!isTripExpenseRpcMissing(code: e.code, message: e.message)) {
        throw _map(e, stack);
      }
    } catch (error, stack) {
      throw _map(error, stack);
    }
    try {
      final row = await _client
          .from('trips')
          .select('expenses')
          .eq('id', tripId)
          .eq('tenant_id', tenantId)
          .single();
      final raw = row['expenses'];
      final current = [
        if (raw is List)
          for (final e in raw)
            if (e is Map) Map<String, dynamic>.from(e),
      ];
      final next = applyTripExpenseChange(current, change);
      if (identical(next, current)) return;
      await _client
          .from('trips')
          .update({'expenses': next})
          .eq('id', tripId)
          .eq('tenant_id', tenantId);
    } on StateError catch (e) {
      throw ValidationFailure(e.message, cause: e);
    } catch (error, stack) {
      throw _map(error, stack);
    }
  }

  /// The RPCs raise P0002 (gone / not allowed) and 22023 (bad input) with a
  /// message written for the person; show it as it is.
  Failure _map(Object error, StackTrace stack) {
    if (error is PostgrestException &&
        (error.code == 'P0002' || error.code == '22023')) {
      return ValidationFailure(error.message, cause: error);
    }
    return mapError(error, stack);
  }
}

final tripsGatewayProvider = Provider<TripsGateway>(
  (ref) => SupabaseTripsGateway(ref.watch(supabaseClientProvider)),
  name: 'tripsGateway',
);
