import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/holding_figures.dart';
import '../domain/investment.dart';
import '../domain/stock_lots.dart';
import 'holding_row.dart';

/// The holdings, split by type so stocks and mutual funds never blur
/// together:
///
///   All 7 │ Stocks 4 │ Mutual Funds 2 │ Gold 1     ← type tabs (swipe too)
///   [ Invested | Current · P&L ]                   ← totals for that type
///   ── Stocks · 4 ───────────────── +2,499.72      ← "All" groups by type
///   rows…
///
/// The tabs only appear when there is more than one type. Picking one
/// filters the rows and the summary card both; "All" keeps every row but
/// under a header per type, each with its own P&L.
class HoldingsList extends ConsumerStatefulWidget {
  const HoldingsList({
    super.key,
    required this.items,
    required this.canWrite,
    this.header,
  });

  final List<PortfolioItem> items;
  final bool canWrite;

  /// Shown above everything (the live-prices note).
  final Widget? header;

  @override
  ConsumerState<HoldingsList> createState() => _HoldingsListState();
}

class _HoldingsListState extends ConsumerState<HoldingsList> {
  /// The picked type; null is "All".
  String? _asset;

  /// Rows ticked for a bulk delete (long-press one to start).
  final _selection = BulkSelection();

  @override
  void initState() {
    super.initState();
    _selection.addListener(_changed);
  }

  @override
  void dispose() {
    _selection
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  /// A grouped stock is one row but several purchases; deleting the row
  /// deletes every purchase in it.
  Future<void> _deleteSelected(Map<String, PortfolioItem> byKey) async {
    final controller = ref.read(investmentEditorControllerProvider);
    await deleteSelected(
      context,
      selection: _selection,
      one: 'holding',
      many: 'holdings',
      message: "Every purchase in a grouped holding goes with it. This can't be undone.",
      delete: (key) async {
        final item = byKey[key];
        if (item == null) return;
        for (final r in recordsOf(item)) {
          await controller.delete(r.id);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final types = assetBreakdown(widget.items);
    // The picked type may have gone (its last holding deleted): back to All.
    final asset = types.any((t) => t.asset == _asset) ? _asset : null;
    final shown = asset == null
        ? widget.items
        : widget.items.where((i) => assetOf(i) == asset).toList();
    final summary = summarisePortfolio(shown.expand(recordsOf), prices);
    final line = Divider(height: 1, thickness: 1, color: context.palette.line);

    String keyOf(PortfolioItem item) => switch (item) {
      GroupedHolding(:final group) => 'g:${group.key}',
      SingleHolding(:final record) => record.id,
    };
    final byKey = {for (final i in widget.items) keyOf(i): i};

    Widget row(PortfolioItem item) {
      final k = keyOf(item);
      return HoldingRow(
        key: ValueKey(k),
        item: item,
        canWrite: widget.canWrite,
        selecting: _selection.active,
        selected: _selection.contains(k),
        onToggle: () => _selection.toggle(k),
        onLongPress: widget.canWrite ? () => _selection.start(k) : null,
      );
    }

    // Tab 0 is All, then one per type, in the same order as the tab row.
    final index = asset == null
        ? 0
        : types.indexWhere((t) => t.asset == asset) + 1;

    final list = ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            0,
            AppSpacing.screenGutter,
            AppSpacing.lg,
          ),
          child: _SummaryCard(summary: summary),
        ),
        line,
        if (asset == null && types.length > 1)
          for (final t in types) ...[
            _TypeHeader(
              asset: t.asset,
              count: t.count,
              items: [
                for (final i in widget.items)
                  if (assetOf(i) == t.asset) i,
              ],
              prices: prices,
            ),
            line,
            for (final i in widget.items)
              if (assetOf(i) == t.asset) ...[row(i), line],
          ]
        else
          for (final i in shown) ...[row(i), line],
      ],
    );

    // The tab row stays put while the list scrolls under it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenGutter,
            AppSpacing.xs,
            AppSpacing.screenGutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selection.active) ...[
                SelectionBar(
                  selection: _selection,
                  shown: [for (final i in shown) keyOf(i)],
                  onDelete: () => _deleteSelected(byKey),
                ),
                const SizedBox(height: AppSpacing.md),
              ] else
                ?widget.header,
              if (types.length > 1) ...[
                _TypeTabs(
                  total: widget.items.length,
                  types: types,
                  selected: asset,
                  onSelected: (a) => setState(() => _asset = a),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
        Expanded(
          // Swipe right-to-left for the next type, left-to-right for the
          // previous one; the tab row follows.
          child: types.length > 1
              ? SwipeTabs(
                  index: index,
                  count: types.length + 1,
                  onChanged: (i) => setState(
                    () => _asset = i == 0 ? null : types[i - 1].asset,
                  ),
                  child: list,
                )
              : list,
        ),
      ],
    );
  }
}

/// "All 7 │ Stocks 4 │ Mutual Funds 2": underlined text tabs, lighter than
/// the Holdings / Price alerts pills above so the two never read as one row.
class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.total,
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  final int total;
  final List<({String asset, int count})> types;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget tab(String? asset, String label, int count) {
      final on = asset == selected;
      return RevealWhenSelected(
        selected: on,
        child: Semantics(
          button: true,
          selected: on,
          label: '$label, $count',
          excludeSemantics: true,
          child: InkWell(
            key: Key('asset-tab-${asset ?? 'all'}'),
            onTap: () => onSelected(asset),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
                6,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: on ? palette.accentText : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodyStrong.copyWith(
                      color: on ? palette.accentText : palette.muted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: on ? Tones.accent(context).bg : palette.card,
                      borderRadius: BorderRadius.circular(999),
                      border: on ? null : Border.all(color: palette.line),
                    ),
                    child: Text(
                      '$count',
                      style: AppTypography.label.copyWith(
                        color: on ? palette.accentText : palette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          tab(null, 'All', total),
          for (final t in types) ...[
            const SizedBox(width: AppSpacing.xs),
            tab(t.asset, assetLabel(t.asset), t.count),
          ],
        ],
      ),
    );
  }
}

/// The band above each type in "All": the type and its count on the left,
/// that type's P&L and return on the right edge, where the rows' figures sit.
class _TypeHeader extends StatelessWidget {
  const _TypeHeader({
    required this.asset,
    required this.count,
    required this.items,
    required this.prices,
  });

  final String asset;
  final int count;
  final List<PortfolioItem> items;
  final Map<String, double> prices;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final s = summarisePortfolio(items.expand(recordsOf), prices);
    final gain = s.gain.amount.toDouble();
    final color = gain >= 0 ? context.finance.income : context.finance.expense;
    final pct = s.invested.amount.sign == 0 ? null : s.returnPct;

    return Container(
      key: Key('type-header-$asset'),
      color: palette.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${assetLabel(asset)}  ·  $count',
              style: AppTypography.bodyStrong.copyWith(color: palette.ink),
            ),
          ),
          Text(
            '${signedAmount(gain, s.current.currency)}  ${signedPct(pct)}',
            style: AppTypography.label.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Invested | Current on top, then P&L with its return as a pill.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final up = summary.gain.amount.sign >= 0;
    final cur = summary.current.currency;
    const tabular = [FontFeature.tabularFigures()];
    final label = AppTypography.label.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    final figure = AppTypography.title.copyWith(
      color: palette.ink,
      fontFeatures: tabular,
    );

    Widget cell(String name, double v, CrossAxisAlignment align) => Column(
      crossAxisAlignment: align,
      children: [
        Text(name, style: label),
        const SizedBox(height: 4),
        Text(plainAmount(v, cur), style: figure),
      ],
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.sm,
            spacing: AppSpacing.md,
            children: [
              cell(
                'Invested',
                summary.invested.amount.toDouble(),
                CrossAxisAlignment.start,
              ),
              cell(
                'Current',
                summary.current.amount.toDouble(),
                CrossAxisAlignment.end,
              ),
            ],
          ),
          Divider(height: AppSpacing.xl, color: palette.line),
          Row(
            children: [
              Text(
                'P&L',
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  children: [
                    Text(
                      signedAmount(summary.gain.amount.toDouble(), cur),
                      key: const Key('summary-pnl'),
                      style: AppTypography.title.copyWith(
                        color: up
                            ? context.finance.income
                            : context.finance.expense,
                        fontFeatures: tabular,
                      ),
                    ),
                    TonePill(
                      signedPct(
                        summary.invested.amount.sign == 0
                            ? null
                            : summary.returnPct,
                      ),
                      up ? Tones.mint(context) : Tones.coral(context),
                      dot: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
