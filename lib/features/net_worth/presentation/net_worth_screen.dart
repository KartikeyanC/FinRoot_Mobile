import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/net_worth_editor_controller.dart';
import '../application/net_worth_providers.dart';
import '../domain/net_worth.dart';
import 'entry_form_sheet.dart';

/// Net worth (M11) — assets minus liabilities: the rows the person adds, plus
/// accounts, investments and loans pulled in read-only (the web Net Worth page
/// does the same). Menu-gated. Online-only (not cached).
class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.netWorth)) ==
        MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Net worth',
        body: MenuLockedView(
          feature: 'Net worth',
          icon: Icons.balance_outlined,
        ),
      );
    }

    final entries = ref.watch(netWorthEntriesProvider);
    final all = ref.watch(netWorthAllEntriesProvider);
    final totals = ref.watch(netWorthTotalsProvider);
    final history = ref.watch(netWorthHistoryProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasEntries = all.isNotEmpty;

    return AppPage(
      title: 'Net worth',
      padBody: false,
      floatingActionButton: canWrite && hasEntries
          ? AddFab(
              label: 'Item',
              onPressed: () => openNetWorthEntryForm(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(netWorthEntriesProvider);
          ref.invalidate(netWorthHistoryProvider);
        },
        child: entries.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            e,
            onRetry: () => ref.invalidate(netWorthEntriesProvider),
          ),
          data: (_) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.xs,
              AppSpacing.screenGutter,
              96,
            ),
            children: [
              if (all.isEmpty)
                _Empty(canWrite: canWrite)
              else ...[
                _HeadlineCard(
                  totals: totals,
                  history: history.value ?? const [],
                ),
                _GroupSection(
                  title: 'Assets',
                  entries: all.where((e) => e.isAsset).toList(),
                  total: totals.assets,
                  canWrite: canWrite,
                ),
                _GroupSection(
                  title: 'Liabilities',
                  entries: all.where((e) => !e.isAsset).toList(),
                  total: totals.liabilities,
                  canWrite: canWrite,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.totals, required this.history});
  final NetWorthTotals totals;
  final List<NetWorthPoint> history;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;

    String? status;
    var up = true;
    if (history.length >= 2) {
      final delta = history.last.netWorth - history.first.netWorth;
      up = delta.amount.sign >= 0;
      status =
          '${up ? '+' : '-'}${delta.abs.formatShort()} since '
          '${RelativeTime.dayLabel(history.first.capturedOn)}';
    }

    return MetricCard(
      eyebrow: 'Net worth',
      figure: totals.netWorth.formatShort(),
      status: status ?? 'Assets minus liabilities',
      statusColor: status == null
          ? palette.muted
          : (up ? finance.income : finance.expense),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (history.length >= 2) ...[
            _Sparkline(
              values: [
                for (final p in history) p.netWorth.amount.toDouble(),
              ],
              color: up ? finance.income : finance.expense,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SplitBar([
            BarSegment(
              'Assets',
              totals.assets.amount.toDouble(),
              palette.accent,
              amountLabel: totals.assets.formatShort(),
            ),
            BarSegment(
              'Liabilities',
              totals.liabilities.amount.toDouble(),
              Tones.coral(context).fg,
              amountLabel: totals.liabilities.formatShort(),
            ),
          ]),
        ],
      ),
    );
  }
}

/// A tiny history line under the headline figure (net worth per snapshot).
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: CustomPaint(
      painter: _SparklinePainter(values, color),
      size: Size.infinite,
    ),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo).abs() < 1e-9 ? 1.0 : hi - lo;
    const pad = 4.0;
    Offset at(int i) => Offset(
      pad + (size.width - 2 * pad) * i / (values.length - 1),
      pad + (size.height - 2 * pad) * (1 - (values[i] - lo) / span),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(values.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}

IconData _iconForGroup(String group) => switch (group) {
  'liquid' => Icons.payments_outlined,
  'bank' => Icons.account_balance_outlined,
  'mutual_funds' => Icons.pie_chart_outline,
  'stocks' => Icons.show_chart,
  'credit_card' => Icons.credit_card_outlined,
  'car_loan' => Icons.directions_car_outlined,
  'home_loan' => Icons.home_outlined,
  'personal_loan' => Icons.person_outline,
  'other_liability' => Icons.receipt_long_outlined,
  _ => Icons.category_outlined,
};

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.entries,
    required this.total,
    required this.canWrite,
  });

  final String title;
  final List<NetWorthEntry> entries;
  final Money total;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final isAsset = entries.first.isAsset;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title,
          trailing: Text(
            total.formatShort(),
            style: AppTypography.bodyStrong.copyWith(
              color: isAsset ? context.palette.ink : context.finance.expense,
            ),
          ),
        ),
        for (final e in entries) _EntryRow(entry: e, canWrite: canWrite),
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.canWrite});
  final NetWorthEntry entry;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = entry.isAsset ? Tones.mint(context) : Tones.coral(context);
    final source = entry.source;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListRow(
        key: ValueKey('nw-${entry.id}'),
        // A synced row is changed where it comes from.
        onTap: source != null
            ? () => context.push(source.route)
            : canWrite
            ? () => openNetWorthEntryForm(context, editing: entry)
            : null,
        leading: ToneTile(icon: _iconForGroup(entry.group), tone: tone),
        title: entry.name,
        subtitle: source == null
            ? groupLabel(entry.group)
            : '${groupLabel(entry.group)} · ${source.label}',
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.5,
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AmountText(
                entry.amount.amount.toDouble(),
                currency: entry.amount.currency,
                signed: false,
                color: entry.isAsset ? null : context.finance.expense,
              ),
            ),
            if (canWrite && source == null)
              RowMenu(
                tooltip: 'Entry actions',
                onSelected: (v) async {
                  if (v == 'edit') {
                    unawaited(
                      openNetWorthEntryForm(context, editing: entry),
                    );
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await ref
                        .read(netWorthEditorControllerProvider)
                        .delete(entry.id);
                  } on Failure catch (f) {
                    messenger.showSnackBar(SnackBar(content: Text(f.message)));
                  }
                },
                items: const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: CardEmpty(
        icon: Icons.balance_outlined,
        title: 'Build the picture',
        message:
            'Your accounts, investments and loans show up here on their own. '
            'Add anything else you own or owe: the difference is your net '
            'worth, and the app tracks it over time.',
        actionLabel: canWrite ? 'Add an item' : null,
        onAction: canWrite ? () => openNetWorthEntryForm(context) : null,
      ),
    );
  }
}
