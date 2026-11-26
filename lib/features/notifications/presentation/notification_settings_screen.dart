import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../application/notification_settings.dart';
import '../data/notification_permission.dart';
import '../data/notification_service.dart';

/// Settings → Notifications: whether Android lets FinRoot notify at all, which
/// kinds of reminder to schedule, how early renewals and premiums are flagged,
/// and the time they arrive. Changes reschedule at once (the coordinator
/// listens to [notificationSettingsProvider]).
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Back from the phone's settings → read the permission again.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(notificationsAllowedProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(notificationSettingsProvider);
    final c = ref.read(notificationSettingsProvider.notifier);
    final palette = context.palette;

    return AppPage(
      title: 'Notifications',
      subtitle: 'Which reminders arrive, and when',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          const _PermissionCard(),

          const SectionTitle('Remind me about'),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KindSwitch(
                  key: const ValueKey('notify-recurring'),
                  title: 'Recurring items',
                  subtitle:
                      'Bills and income with a bell on, as early as '
                      'each item\'s bell says',
                  value: s.recurring,
                  onChanged: c.setRecurring,
                ),
                _KindSwitch(
                  key: const ValueKey('notify-reminders'),
                  title: 'Reminders',
                  subtitle: 'On the day each reminder is due',
                  value: s.reminders,
                  onChanged: c.setReminders,
                ),
                _KindSwitch(
                  key: const ValueKey('notify-subscriptions'),
                  title: 'Subscription renewals',
                  subtitle: 'Before a tracked subscription renews',
                  value: s.subscriptions,
                  onChanged: c.setSubscriptions,
                ),
                if (s.subscriptions)
                  _LeadPicker(
                    key: const ValueKey('notify-subscription-lead'),
                    selected: s.subscriptionLeadDays,
                    onSelected: c.setSubscriptionLead,
                  ),
                _KindSwitch(
                  key: const ValueKey('notify-insurance'),
                  title: 'Insurance premiums',
                  subtitle: 'Before a policy premium is due',
                  value: s.insurance,
                  onChanged: c.setInsurance,
                ),
                if (s.insurance)
                  _LeadPicker(
                    key: const ValueKey('notify-insurance-lead'),
                    selected: s.insuranceLeadDays,
                    onSelected: c.setInsuranceLead,
                  ),
              ],
            ),
          ),

          const SectionTitle('Time'),
          ListRow(
            key: const ValueKey('notify-time'),
            icon: Icons.schedule_rounded,
            title: MaterialLocalizations.of(context).formatTimeOfDay(s.time),
            subtitle: 'When reminders arrive on the day they fire',
            trailing: Icon(Icons.edit_outlined, size: 20, color: palette.muted),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: s.time,
                helpText: 'Remind me at',
              );
              if (picked != null) await c.setTime(picked);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'These choices are for this phone only. Price alerts are set on '
            'each stock and are not affected.',
            style: AppTypography.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      title,
      style: AppTypography.bodyStrong.copyWith(color: context.palette.ink),
    ),
    subtitle: Text(subtitle),
    value: value,
    onChanged: onChanged,
  );
}

class _LeadPicker extends StatelessWidget {
  const _LeadPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: FilterPills<int>(
      options: [
        for (final d in kNotifyLeadOptions) FilterPill(d, notifyLeadLabel(d)),
      ],
      selected: selected,
      onSelected: onSelected,
    ),
  );
}

/// Android's own switch for FinRoot's notifications. Nothing here works while
/// it is off, so say so and offer the way back.
class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(notificationsAllowedProvider).value;
    final palette = context.palette;
    final finance = context.finance;

    // Unknown (not Android, or still reading) → nothing to act on.
    if (allowed == null) return const SizedBox.shrink();

    return AppCard(
      key: const ValueKey('notify-permission'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allowed
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: allowed ? finance.success : finance.danger,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  allowed
                      ? 'Notifications are allowed'
                      : 'Notifications are off for FinRoot',
                  style: AppTypography.bodyStrong.copyWith(color: palette.ink),
                ),
              ),
            ],
          ),
          if (!allowed) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Android is blocking FinRoot\'s notifications, so none of the '
              'reminders below will show until you allow them.',
              style: AppTypography.caption.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('notify-allow'),
              onPressed: () => _allow(ref),
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Allow notifications'),
            ),
          ],
        ],
      ),
    );
  }

  /// Ask first; once Android has stopped showing the prompt (denied before),
  /// the ask comes back false at once, so open the phone's settings instead.
  Future<void> _allow(WidgetRef ref) async {
    final service = ref.read(notificationServiceProvider);
    await service.init();
    final granted = await service.requestPermission();
    if (!granted) {
      await ref.read(notificationPermissionsProvider).openSettings();
    }
    ref.invalidate(notificationsAllowedProvider);
  }
}
