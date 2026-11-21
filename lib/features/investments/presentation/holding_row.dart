import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart' show alertTargetFor;
import '../../price_alerts/presentation/price_alerts_screen.dart'
    show openHoldingAlerts;
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/bond.dart';
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
///
/// Long-press ticks it for a bulk delete ([onLongPress]); while its list is
/// [selecting], a check circle leads the row and a tap toggles it.
class HoldingRow extends ConsumerWidget {
  const HoldingRow({
    super.key,
    required this.item,
    required this.canWrite,
    this.selecting = false,
    this.selected = false,
    this.onToggle,
    this.onLongPress,
  });

  final PortfolioItem item;
  final bool canWrite;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;

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

    final bond = h.record.bond;
    final top = [
      if (bond != null) ...bondCardLine(bond, invested: h.invested),
      if (h.qty > 0) 'Qty. ${qtyLabel(h.qty)}',
      if (h.avgPrice > 0) 'Avg. ${plainAmount(h.avgPrice, h.currency)}',
      if (h.isGroup) '${h.lots.length} buys',
    ];

    return Semantics(
      button: true,
      selected: selecting ? selected : null,
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        child: InkWell(
          onLongPress: onLongPress,
          onTap: selecting
              ? onToggle
              : () => showHoldingSheet(
                  context,
                  item: item,
                  canWrite: canWrite,
                  onEdit: (r) => openInvestmentForm(context, editing: r),
                  onDelete: (r, what) => deleteHolding(context, ref, r, what),
                  onNeedTicker: () => _needTicker(context, h.record),
                ),
          child: Padding(
            // No bottom padding here: the last line supplies it, so the
            // alarm tag's 48dp target can hang into it.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.md,
              AppSpacing.screenGutter,
              0,
            ),
            child: Row(
              children: [
                if (selecting) ...[
                  SelectCheck(on: selected),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Qty and average price | return on what was paid.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              top.isEmpty
                                  ? assetLabel(h.asset)
                                  : top.join('  •  '),
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
                      // Invested (+ alarm tag) | total = invested + profit. Total
                      // stays on the Invested line when the tag wraps below it.
                      // The 6dp gap above this line and the row's bottom
                      // padding live inside it, so the alarm tag's 48dp target
                      // can span them.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: AppSpacing.xs,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: alarmTagInset,
                                    right: AppSpacing.xs,
                                    bottom: AppSpacing.md,
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Invt. ',
                                          semanticsLabel: 'Invested ',
                                          style: muted,
                                        ),
                                        TextSpan(
                                          text: plainAmount(
                                            h.invested,
                                            h.currency,
                                          ),
                                          style: strong,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (h.canAlert)
                                  HoldingAlarmTag(
                                    symbol: h.symbol,
                                    name: h.name,
                                    currency: h.currency,
                                    canWrite: canWrite,
                                    onNeedTicker: () =>
                                        _needTicker(context, h.record),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Padding(
                            padding: const EdgeInsets.only(
                              top: alarmTagInset,
                              bottom: AppSpacing.md,
                            ),
                            child: Text.rich(
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
                          ),
                        ],
                      ),
                    ],
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

/// How far the alarm tag's visual sits below the top of its 48dp target:
/// the gap between the name line and the "Invt." line.
const alarmTagInset = 6.0;

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
    // The "Invt." line it sits on: 13sp at the label style's 16/12 height.
    final lineHeight = MediaQuery.textScalerOf(context).scale(13) * 16 / 12;
    final onTap = sym == null
        ? onNeedTicker
        : () => openHoldingAlerts(context, ref, symbol: sym, name: name);

    // A 48dp target around a small visual. The visual sits [alarmTagInset]
    // from the top, level with the "Invt." line; the rest of the target hangs
    // into the row's bottom padding, so the figures keep their rhythm.
    return Tooltip(
      message: t == null ? 'Set a price alert' : 'Price alerts',
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: t == null ? 'Set a price alert' : null,
        child: InkResponse(
          key: const Key('holding-alarm'),
          onTap: onTap,
          radius: 24,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppSpacing.minTouchTarget,
              minHeight: AppSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: alarmTagInset),
              // Left-aligned, one text line tall: the visual sits right after
              // "Invt." and centred on its line at any text size; the spare
              // target extends right and down into empty space.
              child: Align(
                alignment: Alignment.topLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: lineHeight),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: t == null
                        ? Icon(
                            Icons.alarm_add_rounded,
                            size: 16,
                            color: palette.faint,
                          )
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
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The bond facts on a holding card's top line: maturity, then the next
/// payout while one is still to come.
List<String> bondCardLine(
  BondTerms bond, {
  required double invested,
  DateTime? asOf,
}) {
  final today = asOf ?? DateTime.now();
  final end = bond.maturityDate;
  if (end == null) return const [];
  final fmt = DateFormat('d MMM yyyy');
  final f = BondFigures.of(bond, invested: invested, asOf: today);
  final next = f.nextPayout;
  final matured = !end.isAfter(DateTime(today.year, today.month, today.day));
  return [
    matured ? 'Matured ${fmt.format(end)}' : 'Matures ${fmt.format(end)}',
    if (next != null && next != end) 'Next payout ${fmt.format(next)}',
  ];
}
