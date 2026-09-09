import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/application/workspace_providers.dart';
import '../data/reminders_gateway.dart';
import '../domain/reminder.dart';

/// Standalone reminders — live from PostgREST (not cached). Each row is passed
/// through [Reminder.rolledForward] so a past-due recurring reminder shows its
/// next occurrence and a stale one-off reads as completed (no write-on-read).
final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  final rows = await ref.watch(remindersGatewayProvider).list(tenantId);
  return [for (final r in rows) r.rolledForward()];
}, name: 'reminders');

/// Active reminders (not completed), soonest first.
final activeRemindersProvider = Provider<List<Reminder>>((ref) {
  final all = ref.watch(remindersProvider).value ?? const [];
  return all.where((r) => !r.isCompleted).toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
}, name: 'activeReminders');
