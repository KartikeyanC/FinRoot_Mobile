import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/application/workspace_providers.dart';
import '../data/goals_repository.dart';
import '../domain/goal.dart';

final goalsProvider = StreamProvider<List<GoalEntity>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const <GoalEntity>[]);
  return ref.watch(goalsRepositoryProvider).watchAll(tenantId);
}, name: 'goals');

final goalByIdProvider = StreamProvider.family<GoalEntity?, String>((ref, id) {
  return ref.watch(goalsRepositoryProvider).watchById(id);
}, name: 'goalById');
