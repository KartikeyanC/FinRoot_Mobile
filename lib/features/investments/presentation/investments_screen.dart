import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart'
    show alertLabelFor, formatPrice;
import '../../price_alerts/presentation/price_alerts_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import '../domain/stock_lots.dart';
import 'holding_card.dart';
import 'investment_form_sheet.dart';
import 'stock_group_tile.dart';

/// Investments (M11) — a simple portfolio: invested vs current per holding,
/// totals and a return figure. Menu-gated (ADR-0002). Online-only (not cached).
/// The web keeps the per-asset calculators and demat integration.
class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.investments)) ==
        MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Investments',
        body: MenuLockedView(feature: 'Investments', icon: Icons.trending_up),
      );
    }

    final records = ref.watch(investmentsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasHoldings = records.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Investments',
      padBody: false,
      floatingActionButton: canWrite && hasHoldings
          ? AddFab(
              label: 'Holding',
              onPressed: () => openInvestmentForm(context),
            )
          : null,
      body: RefreshIndicator(
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
                    const SizedBox(height: AppSpacing.md),
                    const _AlertsPill(),
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
      ),
    );
  }
}

class _AlertsPill extends ConsumerWidget {
  const _AlertsPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final watching = alerts.where((a) => a.isActive).length;
    return InfoPill(
      icon: Icons.notifications_active_outlined,
      text: 'Price alerts',
      detail: watching == 0 ? 'Set a buy price' : '$watching watching',
      onTap: () => context.push(priceAlertsPath),
    );
  }
}

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
      figure: summary.current.formatShort(),
      figureSuffix: 'invested ${summary.invested.formatShort()}',
      status:
          '${up ? '+' : ''}${summary.gain.formatShort()} '
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
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];

    final avg = lot.price > 0 && symbol != null
        ? formatPrice(symbol, lot.price)
        : null;
    final alert = symbol == null ? null : alertLabelFor(symbol, alerts);
    final facts = record.asset == 'stocks' && (avg != null || alert != null)
        ? HoldingFacts(avgPrice: avg, alert: alert)
        : null;

    return HoldingCard(
      icon: assetIcon(record.asset),
      tone: _toneForAsset(context, record.asset),
      title: record.name,
      subtitle: assetLabel(record.asset),
      live: live != null && symbol != null
          ? 'Live ${formatPrice(symbol, live.unitPrice)} · $symbol'
          : null,
      hint: symbol == null && canWrite && isPriceableAsset(record.asset)
          ? 'Add a ticker to see the live price'
          : null,
      onHintTap: () => openInvestmentForm(context, editing: record),
      facts: facts,
      value: liveValue != null
          ? formatPrice(symbol ?? '', liveValue)
          : record.current.formatShort(),
      gainLabel:
          '${up ? '+' : ''}${Money(Decimal.parse(gain.toStringAsFixed(2))).formatShort()}',
      up: up,
      onTap: canWrite
          ? () => openInvestmentForm(context, editing: record)
          : null,
      menu: canWrite
          ? RowMenu(
              onSelected: (v) {
                if (v == 'edit') {
                  openInvestmentForm(context, editing: record);
                } else if (v == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              items: const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
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
