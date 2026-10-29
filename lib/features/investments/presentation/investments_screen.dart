import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/domain/price_alert.dart' show alertLabelFor, formatPrice;
import '../../price_alerts/presentation/price_alerts_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import '../domain/stock_lots.dart';
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
      return Scaffold(
        appBar: AppBar(title: const Text('Investments')),
        body: const MenuLockedView(
          feature: 'Investments',
          icon: Icons.trending_up,
        ),
      );
    }

    final records = ref.watch(investmentsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
        actions: [
          IconButton(
            tooltip: 'Price alerts',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => context.push(priceAlertsPath),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openInvestmentForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Holding'),
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
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.huge,
                  ),
                  children: [
                    const _LivePriceTicker(),
                    _SummaryCard(summary: summary),
                    const SizedBox(height: AppSpacing.lg),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final up = summary.gain.amount.sign >= 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current value',
            style: tt.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xxs),
          AmountText.money(
            summary.current,
            size: AmountSize.hero,
            signed: false,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Invested ${summary.invested.formatShort()}',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${up ? '+' : ''}${summary.gain.formatShort()} '
                '(${summary.returnPct.toStringAsFixed(1)}%)',
                style: tt.bodySmall?.copyWith(
                  color: up ? finance.income : finance.expense,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoldingTile extends ConsumerWidget {
  const _HoldingTile({required this.record, required this.canWrite});
  final InvestmentRecord record;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final up = record.gain.amount.sign >= 0;
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final live = liveFor(record, prices);
    final symbol = resolveLiveSymbol(record)?.symbol;
    final lot = toLot(record);
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: canWrite
            ? () => openInvestmentForm(context, editing: record)
            : null,
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                assetIcon(record.asset),
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
                    record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    assetLabel(record.asset),
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (live != null && symbol != null)
                    Text(
                      'Live ${formatPrice(symbol, live.unitPrice)} · $symbol',
                      style: tt.labelSmall?.copyWith(
                        color: finance.income,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (record.asset == 'stocks')
                    HoldingFacts(
                      avgPrice: lot.price > 0 && symbol != null
                          ? formatPrice(symbol, lot.price)
                          : null,
                      alert: symbol == null ? null : alertLabelFor(symbol, alerts),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (live?.value case final v?)
                  Text(
                    formatPrice(symbol ?? '', v),
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  )
                else
                  AmountText.money(record.current, signed: false),
                Text(
                  '${up ? '+' : ''}${record.gain.formatShort()}',
                  style: tt.labelSmall?.copyWith(
                    color: up ? finance.income : finance.expense,
                  ),
                ),
              ],
            ),
            if (canWrite)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    openInvestmentForm(context, editing: record);
                  } else if (v == 'delete') {
                    _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${record.name}"?'),
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
    return ListView(
      children: [
        const SizedBox(height: AppSpacing.huge),
        EmptyView(
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
        ),
      ],
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
