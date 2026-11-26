import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/trips_gateway.dart';
import '../domain/trip.dart';

final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(tripsGatewayProvider).list(tenantId);
}, name: 'trips');

/// One trip by id, from [tripsProvider] (null when it is gone).
final tripProvider = Provider.family<AsyncValue<Trip?>, String>((ref, id) {
  return ref.watch(tripsProvider).whenData((list) {
    for (final t in list) {
      if (t.id == id) return t;
    }
    return null;
  });
}, name: 'trip');

class TripsController {
  TripsController(this._ref);
  final Ref _ref;

  String _writableTenant() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    return tenantId;
  }

  /// Create a trip; returns its id.
  Future<String> create(NewTrip trip) async {
    final tenantId = _writableTenant();
    final id = await _ref.read(tripsGatewayProvider).create(tenantId, trip);
    _ref.invalidate(tripsProvider);
    return id;
  }

  Future<void> addExpense(String tripId, TripExpense expense) =>
      _change(tripId, AddTripExpense(expense));

  Future<void> updateExpense(String tripId, TripExpense expense) =>
      _change(tripId, UpdateTripExpense(expense));

  Future<void> removeExpense(String tripId, String expenseId) =>
      _change(tripId, RemoveTripExpense(expenseId));

  /// Move a trip to [currency]; [rate] null keeps the numbers.
  Future<void> setCurrency(
    String tripId,
    String currency, {
    double? rate,
  }) async {
    final tenantId = _writableTenant();
    try {
      await _ref
          .read(tripsGatewayProvider)
          .setCurrency(tenantId, tripId, currency, rate: rate);
    } finally {
      _ref.invalidate(tripsProvider);
    }
  }

  Future<void> _change(String tripId, TripExpenseChange change) async {
    final tenantId = _writableTenant();
    try {
      await _ref
          .read(tripsGatewayProvider)
          .changeExpense(tenantId, tripId, change);
    } finally {
      // Refresh even on failure: "removed from the trip" means the list here
      // is out of date.
      _ref.invalidate(tripsProvider);
    }
  }
}

final tripsControllerProvider = Provider<TripsController>(
  (ref) => TripsController(ref),
  name: 'tripsController',
);
