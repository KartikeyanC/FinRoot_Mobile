import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart' show alertTargetFor;
import '../../price_alerts/presentation/price_alerts_screen.dart'
    show openHoldingAlerts;
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/holding_figures.dart';
import '../domain/investment.dart';
import '../domain/stock_lots.dart';
import 'holding_sheet.dart';
import 'investment_form_sheet.dart';

/// One holding in the list — flat, full width, three aligned rows with the
/// labels down the left edge and every figure on one right edge:
///
///   Qty. 10 • Avg. 410.00                       +6.83%
///   ITC Limited                                +280.00
///   Invt. 4,100.00  [⏰ 400.00]          Total 4,380.00
///
/// "Invt." is short for invested, like Qty. and Avg. (a screen reader still
/// hears "Invested"). The alarm tag sits after it, where a status tag belongs. No ⋮ menu
/// on the row (it pushed the right edge in): tap the row for the detail
/// sheet — LTP, the price alert, each purchase, Edit and Delete. Nothing is
/// ever cut off; a long name or a large text size wraps instead.
class HoldingRow extends ConsumerWidget {
  const HoldingRow({super.key, required this.item, required this.canWrite});

  final PortfolioItem item;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final h = figuresFor(item, prices);
    final palette = context.palette;
    final gainColor = h.up ? context.finance.income : context.finance.expense;
    const tabular = [FontFeature.tabularFigures()];
    final muted = AppTypography.label.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    final strong = muted.copyWith(
      color: palette.ink,
      fontWeight: FontWeight.w600,
      fontFeatures: tabular,
    );

    final top = [
      if (h.qty > 0) 'Qty. ${qtyLabel(h.qty)}',
      if (h.avgPrice > 0) 'Avg. ${plainAmount(h.avgPrice, h.currency)}',
      if (h.isGroup) '${h.lots.length} buys',
    ];

    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => showHoldingSheet(
          context,
          item: item,
          canWrite: canWrite,
          onEdit: (r) => openInvestmentForm(context, editing: r),
          onDelete: (r, what) => deleteHolding(context, ref, r, what),
          onNeedTicker: () => _needTicker(context, h.record),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Qty and average price | return on what was paid.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      top.isEmpty ? assetLabel(h.asset) : top.join('  •  '),
                      style: muted,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    signedPct(h.returnPct),
                    key: const Key('holding-pct'),
                    style: muted.copyWith(
                      color: gainColor,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Name | profit.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      h.name,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    signedAmount(h.gain, h.currency),
                    key: const Key('holding-gain'),
                    style: AppTypography.bodyStrong.copyWith(
                      color: gainColor,
                      fontSize: 16,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Invested (+ alarm tag) | total = invested + profit. Total
              // stays on the Invested line when the tag wraps below it.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Invt. ',
                                semanticsLabel: 'Invested ',
                                style: muted,
                              ),
                              TextSpan(
                                text: plainAmount(h.invested, h.currency),
                                style: strong,
                              ),
                            ],
                          ),
                        ),
                        if (h.canAlert)
                          HoldingAlarmTag(
                            symbol: h.symbol,
                            name: h.name,
                            currency: h.currency,
                            canWrite: canWrite,
                            onNeedTicker: () => _needTicker(context, h.record),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text.rich(
                    key: const Key('holding-total'),
                    TextSpan(
                      children: [
                        TextSpan(text: 'Total ', style: muted),
                        TextSpan(
                          text: plainAmount(h.current, h.currency),
                          style: strong,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _needTicker(BuildContext context, InvestmentRecord record) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Add the ticker first to set a price alert')),
  );
  openInvestmentForm(context, editing: record);
}

/// Confirms, then deletes one holding record. [what] names it in the
/// question ("ITC", "the purchase on 28 Oct 2026").
Future<void> deleteHolding(
  BuildContext context,
  WidgetRef ref,
  InvestmentRecord record,
  String what,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(investmentEditorControllerProvider);
  final ok = await confirmDestructive(context, title: 'Delete $what?');
  if (!ok) return;
  try {
    await controller.delete(record.id);
    messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
  } on Failure catch (f) {
    messenger.showSnackBar(SnackBar(content: Text(f.message)));
  }
}

/// The price alert on a holding: an alarm and the amount ("⏰ 400.00") once
/// one is set — accent while watching, green once it fired — and a quiet
/// alarm-plus icon to set one. Without a ticker it asks for one first.
class HoldingAlarmTag extends ConsumerWidget {
  const HoldingAlarmTag({
    super.key,
    required this.symbol,
    required this.name,
    required this.currency,
    required this.canWrite,
    required this.onNeedTicker,
  });

  final String? symbol;
  final String name;
  final String currency;
  final bool canWrite;
  final VoidCallback onNeedTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = symbol;
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final t = sym == null ? null : alertTargetFor(sym, alerts);
    if (t == null && !canWrite) return const SizedBox.shrink();

    final palette = context.palette;
    final tone = t == null
        ? null
        : (t.triggered ? Tones.mint(context) : Tones.accent(context));
    final onTap = sym == null
        ? onNeedTicker
        : () => openHoldingAlerts(context, ref, symbol: sym, name: name);

    return Semantics(
      button: true,
      label: t == null ? 'Set a price alert' : null,
      child: GestureDetector(
        key: const Key('holding-alarm'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // Wider to tap; no taller than a line of text, so the row's
          // figures stay on one baseline.
          padding: const EdgeInsets.only(right: 6),
          child: t == null
              ? Icon(Icons.alarm_add_rounded, size: 16, color: palette.faint)
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tone!.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.triggered
                            ? Icons.alarm_on_rounded
                            : Icons.alarm_rounded,
                        size: 13,
                        color: tone.fg,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${plainAmount(t.price, currency)}'
                        '${t.more > 0 ? ' +${t.more}' : ''}',
                        style: AppTypography.label.copyWith(
                          color: tone.fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
