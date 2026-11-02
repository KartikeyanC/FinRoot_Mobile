import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../price_alerts/application/price_alerts_providers.dart';
import '../../price_alerts/presentation/price_alerts_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/investments_providers.dart';
import '../domain/stock_lots.dart';
import 'holdings_list.dart';
import 'investment_form_sheet.dart';

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
    final records = ref.watch(investmentsProvider).value ?? const [];
    final hasHoldings = records.isNotEmpty;
    final holdingCount = groupPortfolio(records).length;
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
          FilterPill(
            InvestmentsTab.holdings,
            holdingCount == 0 ? 'Holdings' : 'Holdings · $holdingCount',
          ),
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
            : HoldingsList(
                header: const _LivePriceTicker(),
                // Several purchases of one stock show as one holding.
                items: groupPortfolio(list),
                canWrite: canWrite,
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
