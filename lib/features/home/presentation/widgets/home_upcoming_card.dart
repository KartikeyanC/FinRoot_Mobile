import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../recurring/application/recurring_providers.dart';
import '../../../recurring/domain/recurring_item.dart';
import '../../../reminders/application/reminders_providers.dart';

/// Home "Upcoming" — the nearest recurring items and reminders, merged and
/// sorted by due date (mirrors the web `ActionableReminders`). Reads the same
/// online-only providers the Recurring / Reminders screens use; if neither has
/// loaded (or both are empty), the card hides itself.
class HomeUpcomingCard extends ConsumerWidget {
  const HomeUpcomingCard({super.key});

  static const _horizonDays = 30;
  static const _maxRows = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final rows = <_UpcomingRow>[];

    final recurring = ref.watch(recurringItemsProvider).value ??
        const <RecurringItem>[];
    for (final item in recurring) {
      if (!item.isActive) continue;
      final days = item.daysUntilDue(now: now);
      if (days > _horizonDays) continue;
      rows.add(_UpcomingRow(
        title: item.name,
        subtitle: '${item.category} · ${item.frequency.label}',
        amount: item.amount,
        days: days,
        icon: Icons.event_repeat_outlined,
        route: '/recurring',
      ));
    }

    final remindersLocked =
        ref.watch(menuStatusProvider(FeatureMenu.reminders)) ==
        MenuStatus.locked;
    if (!remindersLocked) {
      for (final r in ref.watch(activeRemindersProvider)) {
        final days = r.daysUntilDue(now: now);
        if (days > _horizonDays) continue;
        rows.add(_UpcomingRow(
          title: r.title,
          subtitle: r.context.label,
          amount: r.amount,
          days: days,
          icon: r.context.icon,
          route: '/reminders',
        ));
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((a, b) => a.days.compareTo(b.days));
    final shown = rows.take(_maxRows).toList();

    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.upcoming_outlined, size: 20,
                  color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text('Upcoming', style: tt.titleSmall),
              const Spacer(),
              if (rows.length > shown.length)
                Text('+${rows.length - shown.length} more',
                    style: tt.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in shown) _UpcomingTile(row: row),
        ],
      ),
    );
  }
}

class _UpcomingRow {
  _UpcomingRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.days,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final Money? amount;
  final int days;
  final IconData icon;
  final String route;
}

class _UpcomingTile extends StatelessWidget {
  const _UpcomingTile({required this.row});
  final _UpcomingRow row;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final soon = row.days <= 2;
    final due = switch (row.days) {
      < 0 => '${-row.days}d overdue',
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in ${row.days}d',
    };

    return InkWell(
      onTap: () => context.push(row.route),
      borderRadius: AppRadius.field,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Icon(row.icon, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${row.amount != null ? '${row.amount!.formatShort()} · ' : ''}'
                      'due $due',
                      style: tt.bodySmall?.copyWith(
                        color: soon ? finance.expense : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
