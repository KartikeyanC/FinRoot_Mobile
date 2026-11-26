import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/providers/providers.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/goal_write_gateway.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';
import '../domain/goal_history.dart';

final goalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <GoalEntity>[]);
  return ref.watch(goalsRepositoryProvider).watchAll(tenantId);
}, name: 'goals');

/// A goal's contribution history from the shared `goal_contributions` table
/// (online read; not cached). [GoalHistory.missing] while the server lacks the
/// table. Throws a `Failure` offline or on a server error — no automatic
/// retry: reopening the sheet (or coming back online) reads again.
final goalHistoryProvider = FutureProvider.autoDispose
    .family<GoalHistory, ({String goalId, String currency})>(
      (ref, key) async {
        final tenantId = ref.watch(currentTenantIdProvider);
        if (tenantId == null) return const GoalHistory([]);
        if (!ref.watch(isOnlineProvider)) throw const NetworkFailure();
        return ref
            .watch(goalWriteGatewayProvider)
            .history(tenantId, key.goalId, key.currency);
      },
      name: 'goalHistory',
      retry: (_, _) => null,
    );

final goalByIdProvider = StreamProvider.family<GoalEntity?, String>((ref, id) {
  return ref.watch(goalsRepositoryProvider).watchById(id);
}, name: 'goalById');
