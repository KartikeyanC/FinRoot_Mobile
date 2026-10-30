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
import 'home_parts.dart';

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

    return HomeSection(
      title: 'Upcoming',
      trailing: rows.length > shown.length
          ? TonePill('+${rows.length - shown.length} more', HomeTone.sky, dot: false)
          : null,
      child: Column(
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: HomeDivider(),
              ),
            _UpcomingTile(row: shown[i]),
          ],
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
    final palette = context.palette;
    final soon = row.days <= 2;
    final due = switch (row.days) {
      < 0 => '${-row.days}d overdue',
      0 => 'today',
      1 => 'tomorrow',
      _ => 'in ${row.days}d',
    };

    return InkWell(
      onTap: () => context.push(row.route),
      borderRadius: AppRadius.tile,
      child: Row(
        children: [
          IconTile(icon: row.icon),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.amount != null ? '${row.amount!.formatShort()} · ' : ''}'
                  'due $due',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    fontWeight: FontWeight.w500,
                    color: soon ? context.finance.expense : palette.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.faint),
        ],
      ),
    );
  }
}
