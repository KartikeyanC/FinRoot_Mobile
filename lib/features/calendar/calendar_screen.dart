import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
import '../transactions/data/transactions_repository.dart';
import '../transactions/domain/transaction.dart';
import '../transactions/presentation/transaction_detail_sheet.dart';
import '../transactions/presentation/widgets/transaction_tile.dart';
import '../workspace/application/workspace_providers.dart';
import 'calendar_events.dart';

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// Cached transactions in the month starting at [month], from the phone's
/// cache (about the last 180 days).
final calendarMonthProvider = StreamProvider.autoDispose
    .family<List<TransactionEntity>, DateTime>((ref, month) {
      final tenantId = ref.watch(currentTenantIdProvider);
      if (tenantId == null) return Stream.value(const []);
      return ref
          .watch(transactionsRepositoryProvider)
          .watchBetween(
            tenantId,
            from: month,
            toExclusive: DateTime(month.year, month.month + 1),
          );
    }, name: 'calendarMonth');

/// [txns] grouped by day of the month (1–31).
Map<int, List<TransactionEntity>> byDay(List<TransactionEntity> txns) {
  final out = <int, List<TransactionEntity>>{};
  for (final t in txns) {
    (out[t.occurredAt.toLocal().day] ??= []).add(t);
  }
  return out;
}

/// A month at a glance, like the web dashboard's Calendar: each day shows a
/// red dot for spending, a green dot for income and an accent dot when
/// something comes due (a reminder, a subscription renewal, a recurring item,
/// an EMI); tap a day for its list. Browses up to a year ahead, where the
/// upcoming items are. Totals stay on the server-derived screens (ADR-0006),
/// so no sums here.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.today});

  /// Injectable "today" for tests.
  final DateTime? today;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final DateTime _today = widget.today ?? DateTime.now();
  late DateTime _month = monthOf(_today);
  late int _day = _today.day;

  /// How far ahead the calendar goes: far enough for a year of renewals and
  /// EMIs.
  static const _monthsAhead = 12;

  void _shift(int months) => setState(() {
    _month = DateTime(_month.year, _month.month + months);
    _day = _month == monthOf(_today) ? _today.day : 1;
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final days = byDay(
      ref.watch(calendarMonthProvider(_month)).value ?? const [],
    );
    final due = eventsByDay(ref.watch(calendarEventsProvider(_month)));
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = _month.weekday % 7; // Sunday first
    final selected = days[_day] ?? const <TransactionEntity>[];
    final selectedDue = due[_day] ?? const <CalendarEvent>[];
    final last = DateTime(_today.year, _today.month + _monthsAhead);

    return AppPage(
      title: 'Calendar',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.xs,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          // The round month switcher: ‹ October 2026 ›
          Material(
            color: palette.card,
            shape: StadiumBorder(side: BorderSide(color: palette.line)),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous month',
                    onPressed: () => _shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next month',
                    onPressed: _month.isBefore(last) ? () => _shift(1) : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                      Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: AppTypography.label.copyWith(
                              color: palette.muted,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                    for (var d = 1; d <= daysInMonth; d++)
                      _DayCell(
                        day: d,
                        selected: d == _day,
                        isToday: monthOf(_today) == _month && d == _today.day,
                        spent:
                            days[d]?.any((t) => t.type == TxnType.expense) ??
                            false,
                        earned:
                            days[d]?.any((t) => t.type == TxnType.income) ??
                            false,
                        due: due[d]?.isNotEmpty ?? false,
                        spendColor: finance.expense,
                        incomeColor: finance.income,
                        dueColor: palette.accent,
                        onTap: () => setState(() => _day = d),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.xs,
                    AppSpacing.sm,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      _LegendDot(color: finance.expense, label: 'Spending'),
                      const SizedBox(width: AppSpacing.lg),
                      _LegendDot(color: finance.income, label: 'Income'),
                      const SizedBox(width: AppSpacing.lg),
                      _LegendDot(color: palette.accent, label: 'Due'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(
            DateFormat('EEEE, d MMMM')
                .format(DateTime(_month.year, _month.month, _day)),
          ),
          if (selected.isEmpty && selectedDue.isEmpty)
            const CardEmpty(
              icon: Icons.event_available_outlined,
              title: 'Nothing on this day.',
              message:
                  'Days with spending, income or something due show a dot on '
                  'the calendar.',
            ),
          for (final e in selectedDue) _DueTile(e),
          for (final t in selected)
            TransactionTile(
              t,
              onTap: () => openTransactionDetail(context, t.id),
            ),
        ],
      ),
    );
  }
}

/// A reminder, renewal, recurring item or EMI on the selected day; tap to
/// open the screen that owns it.
class _DueTile extends StatelessWidget {
  const _DueTile(this.event);
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final palette = context.palette;
    final finance = context.finance;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListRow(
        key: ValueKey('due-${e.id}'),
        icon: switch (e.kind) {
          CalendarEventKind.reminder => Icons.notifications_none_rounded,
          CalendarEventKind.subscription => Icons.subscriptions_outlined,
          CalendarEventKind.recurring => Icons.repeat_rounded,
          CalendarEventKind.emi =>
            e.paid
                ? Icons.check_circle_rounded
                : Icons.account_balance_outlined,
        },
        title: e.title,
        subtitle: e.label,
        trailing: e.amount == null
            ? null
            : Text(
                MoneyFormat.money(e.amount!, currency: e.currency),
                style: AppTypography.bodyStrong.copyWith(
                  color: e.paid
                      ? palette.muted
                      : e.income
                      ? finance.income
                      : palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
        chevron: true,
        onTap: () => context.push(e.route),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: AppTypography.label.copyWith(
          color: context.palette.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.spent,
    required this.earned,
    required this.spendColor,
    required this.incomeColor,
    required this.onTap,
    this.due = false,
    this.dueColor = Colors.transparent,
  });

  final int day;
  final bool selected;
  final bool isToday;
  final bool spent;
  final bool earned;
  final bool due;
  final Color spendColor;
  final Color incomeColor;
  final Color dueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget dot(Color c) => Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        // On the gradient circle the dots need a white edge to stay visible.
        color: selected ? Colors.white : c,
        shape: BoxShape.circle,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label:
          '$day${spent ? ', spending' : ''}${earned ? ', income' : ''}'
          '${due ? ', something due' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected ? palette.gradient : null,
            border: isToday && !selected
                ? Border.all(color: palette.accent, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Text(
                  '$day',
                  style: AppTypography.bodyStrong.copyWith(
                    color: selected ? Colors.white : palette.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (spent) dot(spendColor),
                  if (earned) dot(incomeColor),
                  if (due) dot(dueColor),
                  if (!spent && !earned && !due) const SizedBox(height: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
