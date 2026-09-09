import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workspace/application/workspace_providers.dart';
import '../data/recurring_gateway.dart';
import '../data/recurring_reminders_gateway.dart';
import '../domain/recurring_item.dart';
import '../domain/reminder_setting.dart';

/// The workspace's recurring templates — live from PostgREST (not cached),
/// ordered by next due date. Invalidate to refresh.
final recurringItemsProvider = FutureProvider<List<RecurringItem>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(recurringGatewayProvider).list(tenantId);
}, name: 'recurringItems');

/// Active items of one type, next-due first.
final recurringByTypeProvider =
    Provider.family<List<RecurringItem>, RecurringType>((ref, type) {
  final all = ref.watch(recurringItemsProvider).value ?? const [];
  return all.where((i) => i.isActive && i.type == type).toList()
    ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
}, name: 'recurringByType');

/// itemId → its reminder ("bell") setting. Missing entries mean "off".
final recurringRemindersProvider =
    FutureProvider<Map<String, ReminderSetting>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const {};
  return ref.watch(recurringRemindersGatewayProvider).list(tenantId);
}, name: 'recurringReminders');

/// The reminder setting for one item, resolving a missing row to
/// [ReminderSetting.off].
final reminderSettingForProvider =
    Provider.family<ReminderSetting, String>((ref, itemId) {
  final map = ref.watch(recurringRemindersProvider).value ?? const {};
  return map[itemId] ?? ReminderSetting.off;
}, name: 'reminderSettingFor');
