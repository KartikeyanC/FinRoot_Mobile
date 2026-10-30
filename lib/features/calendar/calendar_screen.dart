import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../design/design.dart';
import '../../domain/constants.dart';
import '../transactions/data/transactions_repository.dart';
import '../transactions/domain/transaction.dart';
import '../transactions/presentation/transaction_detail_sheet.dart';
import '../transactions/presentation/widgets/transaction_tile.dart';
import '../workspace/application/workspace_providers.dart';

/// The first day of [d]'s month.
DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// Cached transactions in the month starting at [month], from the phone's
/// cache (about the last 180 days).
final calendarMonthProvider =
    StreamProvider.autoDispose.family<List<TransactionEntity>, DateTime>((ref, month) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return Stream.value(const []);
  return ref.watch(transactionsRepositoryProvider).watchBetween(
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
/// red dot for spending and a green dot for income; tap a day for its list.
/// Totals stay on the server-derived screens (ADR-0006), so no sums here.
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

  void _shift(int months) => setState(() {
        _month = DateTime(_month.year, _month.month + months);
        _day = _month == monthOf(_today) ? _today.day : 1;
      });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final days = byDay(ref.watch(calendarMonthProvider(_month)).value ?? const []);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = _month.weekday % 7; // Sunday first
    final selected = days[_day] ?? const <TransactionEntity>[];

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
                    onPressed: monthOf(_today) == _month ? null : () => _shift(1),
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
                        spent: days[d]?.any((t) => t.type == TxnType.expense) ?? false,
                        earned: days[d]?.any((t) => t.type == TxnType.income) ?? false,
                        spendColor: finance.expense,
                        incomeColor: finance.income,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(
            DateFormat('EEEE, d MMMM').format(DateTime(_month.year, _month.month, _day)),
          ),
          if (selected.isEmpty)
            const CardEmpty(
              icon: Icons.event_available_outlined,
              title: 'Nothing on this day.',
              message: 'Days with spending or income show a dot on the calendar.',
            )
          else
            for (final t in selected)
              TransactionTile(t, onTap: () => openTransactionDetail(context, t.id)),
        ],
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
  });

  final int day;
  final bool selected;
  final bool isToday;
  final bool spent;
  final bool earned;
  final Color spendColor;
  final Color incomeColor;
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
      label: '$day${spent ? ', spending' : ''}${earned ? ', income' : ''}',
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
                  if (!spent && !earned) const SizedBox(height: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
