import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart'
    show formatPrice;
import '../../price_alerts/presentation/price_alerts_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/full_money.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import '../domain/stock_lots.dart';
import 'holding_card.dart';
import 'investment_form_sheet.dart';
import 'stock_group_tile.dart';

/// The two tabs of the Investments screen.
enum InvestmentsTab { holdings, alerts }

/// Investments (M11) — a simple portfolio: invested vs current per holding,
/// totals and a return figure, with the price alerts as a second tab so they
/// sit next to the holdings they watch. Menu-gated (ADR-0002). Online-only
/// (not cached). The web keeps the per-asset calculators and demat
/// integration.
class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({
    super.key,
    this.initialTab = InvestmentsTab.holdings,
    this.alertSymbol,
    this.alertName,
  });

  final InvestmentsTab initialTab;

  /// When set, the Price alerts tab opens the add-alert sheet pre-filled.
  final String? alertSymbol;
  final String? alertName;

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.investments)) ==
        MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Investments',
        body: MenuLockedView(feature: 'Investments', icon: Icons.trending_up),
      );
    }

    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasHoldings = ref.watch(investmentsProvider).value?.isNotEmpty ?? false;
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final watching = alerts.where((a) => a.isActive).length;

    final Widget? fab = !canWrite
        ? null
        : switch (_tab) {
            InvestmentsTab.holdings when hasHoldings => AddFab(
              label: 'Holding',
              onPressed: () => openInvestmentForm(context),
            ),
            InvestmentsTab.alerts when alerts.isNotEmpty =>
              const PriceAlertFab(),
            _ => null,
          };

    return AppPage(
      title: 'Investments',
      padBody: false,
      header: FilterPills<InvestmentsTab>(
        selected: _tab,
        onSelected: (t) => setState(() => _tab = t),
        options: [
          const FilterPill(InvestmentsTab.holdings, 'Holdings'),
          FilterPill(
            InvestmentsTab.alerts,
            watching == 0 ? 'Price alerts' : 'Price alerts · $watching',
          ),
        ],
      ),
      floatingActionButton: fab,
      body: switch (_tab) {
        InvestmentsTab.holdings => _HoldingsView(canWrite: canWrite),
        InvestmentsTab.alerts => PriceAlertsView(
          initialSymbol: widget.alertSymbol,
          initialName: widget.alertName,
        ),
      },
    );
  }
}

class _HoldingsView extends ConsumerWidget {
  const _HoldingsView({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(investmentsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(investmentsProvider);
        ref.invalidate(holdingPricesProvider);
      },
      child: records.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          e,
          onRetry: () => ref.invalidate(investmentsProvider),
        ),
        data: (list) => list.isEmpty
            ? _Empty(canWrite: canWrite)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenGutter,
                  AppSpacing.xs,
                  AppSpacing.screenGutter,
                  96,
                ),
                children: [
                  const _LivePriceTicker(),
                  _SummaryCard(summary: summary),
                  const SectionTitle('Holdings'),
                  // Several purchases of one stock show as one holding.
                  for (final item in groupPortfolio(list))
                    switch (item) {
                      GroupedHolding(:final group) => StockGroupTile(
                        key: ValueKey(group.key),
                        group: group,
                        canWrite: canWrite,
                      ),
                      SingleHolding(:final record) => _HoldingTile(
                        record: record,
                        canWrite: canWrite,
                      ),
                    },
                ],
              ),
      ),
    );
  }
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

Tone _toneForAsset(BuildContext c, String asset) => switch (asset) {
  'stocks' => Tones.sky(c),
  'mutual_funds' => Tones.violet(c),
  'bonds' => Tones.teal(c),
  'fd' || 'rd' => Tones.butter(c),
  'pf' => Tones.mint(c),
  'gold' => Tones.butter(c),
  'real_estate' => Tones.rose(c),
  'crypto' => Tones.violet(c),
  _ => Tones.accent(c),
};

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final finance = context.finance;
    final up = summary.gain.amount.sign >= 0;
    final colors = [
      for (final e in summary.byAsset) _toneForAsset(context, e.key).fg,
    ];

    return MetricCard(
      eyebrow: 'Current value',
      figure: fullMoney(summary.current),
      figureSuffix: 'invested ${fullMoney(summary.invested)}',
      status:
          '${up ? '+' : ''}${fullMoney(summary.gain)} '
          '(${summary.returnPct.toStringAsFixed(1)}%) overall',
      statusColor: up ? finance.income : finance.expense,
      child: summary.byAsset.length > 1
          ? SplitBar([
              for (var i = 0; i < summary.byAsset.length; i++)
                BarSegment(
                  assetLabel(summary.byAsset[i].key),
                  summary.byAsset[i].value.amount.toDouble(),
                  colors[i],
                ),
            ])
          : null,
    );
  }
}

class _HoldingTile extends ConsumerWidget {
  const _HoldingTile({required this.record, required this.canWrite});
  final InvestmentRecord record;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final gain = effectiveGain(record, prices);
    final up = gain >= 0;
    final live = liveFor(record, prices);
    final liveValue = live?.value;
    final symbol = resolveLiveSymbol(record)?.symbol;
    final lot = toLot(record);

    String cash(double v) =>
        fullMoney(Money(Decimal.parse(v.toStringAsFixed(2)), record.currency));
    final avg = lot.price <= 0
        ? null
        : (symbol != null && !formatPrice(symbol, 0).startsWith('₹')
              ? formatPrice(symbol, lot.price)
              : trimPaise(cash(lot.price)));
    final qtyBits = [
      if (lot.qty > 0) 'Qty ${_qty(lot.qty)}',
      if (lot.qty > 0 && avg != null) 'Avg $avg',
    ];
    final invested = record.invested.amount.toDouble();
    // Stocks and other priced assets can carry an alert; a deposit can't.
    final canAlert = symbol != null || isPriceableAsset(record.asset);
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    void needTicker() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add the ticker first to set a price alert')),
      );
      openInvestmentForm(context, editing: record);
    }

    return HoldingCard(
      title: record.name,
      facts: qtyBits.isEmpty ? [assetLabel(record.asset)] : qtyBits,
      pctLabel: returnPctLabel(gain, invested),
      gainLabel: '${up ? '+' : ''}${cash(gain)}',
      up: up,
      invested: fullMoney(record.invested),
      total: liveValue != null
          ? ((symbol == null || formatPrice(symbol, 0).startsWith('₹'))
                ? cash(liveValue)
                : formatPrice(symbol, liveValue))
          : fullMoney(record.current),
      livePrice: live != null && symbol != null
          ? formatPrice(symbol, live.unitPrice)
          : null,
      alert: canAlert
          ? HoldingAlertChip(
              symbol: symbol,
              name: record.name,
              canWrite: canWrite,
              onNeedTicker: needTicker,
            )
          : null,
      onTap: canWrite
          ? () => openInvestmentForm(context, editing: record)
          : null,
      menu: canWrite
          ? RowMenu(
              onSelected: (v) => switch (v) {
                'edit' => openInvestmentForm(context, editing: record),
                'alert' when symbol == null => needTicker(),
                'alert' => openHoldingAlerts(
                  context,
                  ref,
                  symbol: symbol!,
                  name: record.name,
                ),
                _ => _confirmDelete(context, ref),
              },
              items: holdingMenuItems(
                context,
                canAlert: canAlert,
                hasAlert:
                    symbol != null && alerts.any((a) => a.symbol == symbol),
              ),
            )
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Delete "${record.name}"?',
    );
    if (!ok) return;
    try {
      await ref.read(investmentEditorControllerProvider).delete(record.id);
      messenger.showSnackBar(const SnackBar(content: Text('Holding deleted')));
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.trending_up,
      title: 'No holdings yet',
      message:
          'Track what you have invested and what it is worth now — stocks, '
          'funds, gold, deposits.',
      action: canWrite
          ? FilledButton(
              onPressed: () => openInvestmentForm(context),
              child: const Text('Add a holding'),
            )
          : null,
    );
  }
}

/// Re-asks for live prices every minute while the Investments list is shown.
class _LivePriceTicker extends ConsumerStatefulWidget {
  const _LivePriceTicker();

  @override
  ConsumerState<_LivePriceTicker> createState() => _LivePriceTickerState();
}

class _LivePriceTickerState extends ConsumerState<_LivePriceTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Holdings too, so one added on the laptop appears here within a minute.
    _timer = Timer.periodic(livePriceRefresh, (_) {
      ref.invalidate(investmentsProvider);
      ref.invalidate(holdingPricesProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = ref.watch(livePricesUnavailableProvider);
    if (!unavailable) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: LivePricesUnavailableNote(),
    );
  }
}

/// The quiet note shown when the live-price lookup fails; never a dialog.
class LivePricesUnavailableNote extends StatelessWidget {
  const LivePricesUnavailableNote({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(Icons.cloud_off_outlined, size: 14, color: palette.muted),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Live prices unavailable — showing saved values',
            style: AppTypography.label.copyWith(color: palette.muted),
          ),
        ),
      ],
    );
  }
}
