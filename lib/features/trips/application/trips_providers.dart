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

  Future<void> addExpense(String tripId, TripExpense expense) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    await _ref.read(tripsGatewayProvider).addExpense(tenantId, tripId, expense);
    _ref.invalidate(tripsProvider);
  }
}

final tripsControllerProvider = Provider<TripsController>(
  (ref) => TripsController(ref),
  name: 'tripsController',
);
