import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart';
import '../../price_alerts/presentation/price_alerts_screen.dart'
    show openHoldingAlerts, openPriceAlertSheet;
import '../application/investments_providers.dart';
import '../domain/holding_figures.dart';
import '../domain/investment.dart';
import '../domain/stock_lots.dart';

final _date = DateFormat('d MMM yyyy');

/// The detail sheet a holding row opens: the live price and every figure,
/// its price alert, each purchase (for a stock bought more than once) and
/// Edit / Delete. Edit and Delete close the sheet first and run in the
/// list's context ([onEdit], [onDelete]), so they outlive it.
Future<void> showHoldingSheet(
  BuildContext context, {
  required PortfolioItem item,
  required bool canWrite,
  required void Function(InvestmentRecord record) onEdit,
  required void Function(InvestmentRecord record, String what) onDelete,
  required VoidCallback onNeedTicker,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _HoldingSheet(
    item: item,
    canWrite: canWrite,
    onEdit: onEdit,
    onDelete: onDelete,
    onNeedTicker: onNeedTicker,
  ),
);

class _HoldingSheet extends ConsumerWidget {
  const _HoldingSheet({
    required this.item,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
    required this.onNeedTicker,
  });

  final PortfolioItem item;
  final bool canWrite;
  final void Function(InvestmentRecord record) onEdit;
  final void Function(InvestmentRecord record, String what) onDelete;
  final VoidCallback onNeedTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final h = figuresFor(item, prices);
    final palette = context.palette;
    final gainColor = h.up ? context.finance.income : context.finance.expense;
    String amt(double v) => plainAmount(v, h.currency);

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              h.name,
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: 2),
            Text(
              [?h.symbol, assetLabel(h.asset)].join('  •  '),
              style: AppTypography.label.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                children: [
                  _StatRow(
                    left: ('Qty.', h.qty > 0 ? qtyLabel(h.qty) : '—'),
                    right: ('Avg. price', h.avgPrice > 0 ? amt(h.avgPrice) : '—'),
                  ),
                  _StatRow(
                    left: ('LTP', h.livePrice == null ? '—' : amt(h.livePrice!)),
                    right: ('Return', signedPct(h.returnPct)),
                    rightColor: gainColor,
                  ),
                  _StatRow(
                    left: ('Invested', amt(h.invested)),
                    right: ('Total', amt(h.current)),
                  ),
                  Divider(height: AppSpacing.xl, color: palette.line),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'P&L',
                          style: AppTypography.body.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                      Text(
                        signedAmount(h.gain, h.currency),
                        style: AppTypography.title.copyWith(
                          color: gainColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (h.canAlert) ...[
              const SectionTitle('Price alert'),
              _AlertPanel(
                figures: h,
                canWrite: canWrite,
                onNeedTicker: () => closeThen(onNeedTicker),
              ),
            ],
            if (h.isGroup) ...[
              const SectionTitle('Purchases'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    for (final l in h.lots)
                      _LotRow(
                        lot: l,
                        currency: h.currency,
                        canWrite: canWrite,
                        onEdit: () => closeThen(() => onEdit(l.record)),
                        onDelete: (when) => closeThen(
                          () => onDelete(l.record, 'the purchase on $when'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (canWrite && !h.isGroup) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit holding'),
                      onPressed: () => closeThen(() => onEdit(h.record)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.finance.expense,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                      onPressed: () => closeThen(
                        () => onDelete(h.record, '"${h.name}"'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Two label-over-value cells side by side; the right one ends on the
/// card's right edge so the figures line up down the card.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right, this.rightColor});

  final (String, String) left;
  final (String, String) right;
  final Color? rightColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget cell((String, String) c, CrossAxisAlignment align, Color? color) =>
        Expanded(
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                c.$1,
                style: AppTypography.label.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 2),
              Text(
                c.$2,
                style: AppTypography.bodyStrong.copyWith(
                  color: color ?? palette.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(left, CrossAxisAlignment.start, null),
          const SizedBox(width: AppSpacing.md),
          cell(right, CrossAxisAlignment.end, rightColor),
        ],
      ),
    );
  }
}

/// The holding's price alert in words, with the one action that fits:
/// add a ticker, set an alert, or manage the ones there are.
class _AlertPanel extends ConsumerWidget {
  const _AlertPanel({
    required this.figures,
    required this.canWrite,
    required this.onNeedTicker,
  });

  final HoldingFigures figures;
  final bool canWrite;
  final VoidCallback onNeedTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final sym = figures.symbol;
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final t = sym == null ? null : alertTargetFor(sym, alerts);
    final amount = t == null ? '' : plainAmount(t.price, figures.currency);

    final String text;
    final IconData icon;
    final Color color;
    if (sym == null) {
      text = 'Add the ticker to set a price alert and see the live price';
      icon = Icons.alarm_add_rounded;
      color = palette.muted;
    } else if (t == null) {
      text = 'No price alert yet';
      icon = Icons.alarm_add_rounded;
      color = palette.muted;
    } else if (t.triggered) {
      text = 'Hit $amount';
      icon = Icons.alarm_on_rounded;
      color = context.finance.income;
    } else {
      final dir = t.direction == AlertDirection.below ? 'Falls to' : 'Rises to';
      text = '$dir $amount${t.more > 0 ? '  •  +${t.more} more' : ''}';
      icon = Icons.alarm_rounded;
      color = palette.accentText;
    }

    final (String, VoidCallback)? action = switch ((sym, t)) {
      (null, _) when canWrite => ('Add ticker', onNeedTicker),
      (null, _) => null,
      (final s?, null) when canWrite => (
        'Set alert',
        () => openPriceAlertSheet(context, ref, symbol: s, name: figures.name),
      ),
      (_?, null) => null,
      (final s?, _) => (
        'Manage',
        () => openHoldingAlerts(context, ref, symbol: s, name: figures.name),
      ),
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              key: const Key('holding-alert-action'),
              onPressed: action.$2,
              child: Text(action.$1),
            ),
        ],
      ),
    );
  }
}

class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.currency,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
  });

  final Lot lot;
  final String currency;
  final bool canWrite;
  final VoidCallback onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final when = lot.date == null ? 'Date not set' : _date.format(lot.date!);
    final detail = lot.qty > 0
        ? '${qtyLabel(lot.qty)} × ${plainAmount(lot.price, currency)}'
        : 'Amount only';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  when,
                  style: AppTypography.bodyStrong.copyWith(color: palette.ink),
                ),
                Text(
                  detail,
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          Text(
            plainAmount(lot.invested, currency),
            style: AppTypography.body.copyWith(
              color: palette.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (canWrite)
            RowMenu(
              tooltip: 'Purchase on $when',
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(when),
              items: const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }
}
