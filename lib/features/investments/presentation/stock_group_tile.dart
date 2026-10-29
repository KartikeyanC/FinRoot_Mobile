import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart' show alertLabelFor;
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/live_price.dart';
import '../domain/stock_lots.dart';
import 'investment_form_sheet.dart';

String _money(double v, String currency) =>
    Money(Decimal.parse(v.toStringAsFixed(2)), currency).format();

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

final _date = DateFormat('d MMM yyyy');

/// One stock bought several times, as one holding: total shares, average
/// price, invested and current value. Tap to list every purchase (date,
/// quantity, price), each still editable and deletable on its own.
class StockGroupTile extends ConsumerStatefulWidget {
  const StockGroupTile({super.key, required this.group, required this.canWrite});
  final StockGroup group;
  final bool canWrite;

  @override
  ConsumerState<StockGroupTile> createState() => _StockGroupTileState();
}

class _StockGroupTileState extends ConsumerState<StockGroupTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final current = groupCurrent(g, prices);
    final gain = current - g.invested;
    final up = gain >= 0;
    final live = g.lots
        .map((l) => liveFor(l.record, prices))
        .firstWhere((x) => x != null, orElse: () => null);

    final summary = [
      '${g.lots.length} purchases',
      if (g.qty > 0) '${_qty(g.qty)} shares',
    ].join(' · ');
    final symbol = resolveLiveSymbol(g.lots.first.record)?.symbol;
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final alert = symbol == null ? null : alertLabelFor(symbol, alerts);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(
                    Icons.stacked_line_chart,
                    size: 20,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        summary,
                        style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (live != null)
                        Text(
                          'Live ${_money(live.unitPrice, g.currency)}',
                          style: tt.labelSmall?.copyWith(
                            color: finance.income,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      HoldingFacts(
                        avgPrice: g.avgPrice > 0 ? _money(g.avgPrice, g.currency) : null,
                        alert: alert,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(current, g.currency),
                      style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${up ? '+' : ''}${_money(gain, g.currency)}',
                      style: tt.labelSmall?.copyWith(
                        color: up ? finance.income : finance.expense,
                      ),
                    ),
                  ],
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            if (_open) ...[
              const Divider(height: AppSpacing.lg),
              for (final l in g.lots)
                _LotRow(lot: l, currency: g.currency, canWrite: widget.canWrite),
              const Divider(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    [
                      if (g.qty > 0) '${_qty(g.qty)} sh',
                      'invested ${_money(g.invested, g.currency)}',
                    ].join(' · '),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

class _LotRow extends ConsumerWidget {
  const _LotRow({required this.lot, required this.currency, required this.canWrite});
  final Lot lot;
  final String currency;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final when = lot.date == null ? 'Date not set' : _date.format(lot.date!);
    final detail = lot.qty > 0
        ? '${_qty(lot.qty)} × ${_money(lot.price, currency)}'
        : 'Amount only';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(when, style: tt.bodyMedium),
                Text(
                  detail,
                  style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(_money(lot.invested, currency), style: tt.bodyMedium),
          if (canWrite)
            PopupMenuButton<String>(
              tooltip: 'Purchase on $when',
              onSelected: (v) => v == 'edit'
                  ? openInvestmentForm(context, editing: lot.record)
                  : _confirmDelete(context, ref, when),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String when) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete the purchase on $when?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(investmentEditorControllerProvider).delete(lot.record.id);
      messenger.showSnackBar(const SnackBar(content: Text('Purchase deleted')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

/// "Avg price ₹210" and "Price alert ↓ ₹250" chips under a stock holding.
/// Shows nothing when neither is known.
class HoldingFacts extends StatelessWidget {
  const HoldingFacts({super.key, this.avgPrice, this.alert});
  final String? avgPrice;
  final ({String text, bool triggered})? alert;

  @override
  Widget build(BuildContext context) {
    if (avgPrice == null && alert == null) return const SizedBox.shrink();
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    Widget fact(String label, String value, Color color) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: tt.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: tt.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xxs,
        children: [
          if (avgPrice != null) fact('Avg price', avgPrice!, scheme.onSurface),
          if (alert != null)
            fact(
              'Price alert',
              alert!.text,
              alert!.triggered ? context.finance.income : scheme.primary,
            ),
        ],
      ),
    );
  }
}
