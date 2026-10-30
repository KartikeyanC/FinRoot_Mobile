import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../application/investments_providers.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import 'investment_form_sheet.dart';
import 'investments_screen.dart';

const livePricesPath = '/live-prices';

/// Live prices: every holding that has a ticker, with its price right now,
/// the live value against the saved one, and a way into price alerts.
class LivePricesScreen extends ConsumerStatefulWidget {
  const LivePricesScreen({super.key});

  @override
  ConsumerState<LivePricesScreen> createState() => _LivePricesScreenState();
}

class _LivePricesScreenState extends ConsumerState<LivePricesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(livePriceRefresh, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(investmentsProvider);
    ref.invalidate(holdingPricesProvider);
    ref.invalidate(priceAlertsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.investments)) ==
        MenuStatus.locked;
    if (locked) {
      return const AppPage(
        title: 'Live prices',
        body: MenuLockedView(feature: 'Investments', icon: Icons.trending_up),
      );
    }

    final records = ref.watch(investmentsProvider);
    final unavailable = ref.watch(livePricesUnavailableProvider);

    return AppPage(
      title: 'Live prices',
      subtitle: 'Refreshes every minute while this screen is open.',
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: records.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            e,
            onRetry: () => ref.invalidate(investmentsProvider),
          ),
          data: (list) {
            final priced = [
              for (final r in list)
                if (resolveLiveSymbol(r) != null) r,
            ];
            final missing = [
              for (final r in list)
                if (isPriceableAsset(r.asset) && resolveLiveSymbol(r) == null) r,
            ];
            if (priced.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 420,
                    child: EmptyView(
                      icon: Icons.show_chart,
                      title: 'No live prices yet',
                      message:
                          'Add a ticker to a stock, crypto or fund holding to '
                          'see live prices.',
                      action: PillButton(
                        label: 'Open investments',
                        icon: Icons.trending_up,
                        onPressed: () => context.push('/investments'),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                if (unavailable)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: LivePricesUnavailableNote(),
                  ),
                for (final r in priced)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _PriceRow(record: r),
                  ),
                if (missing.isNotEmpty) ...[
                  const SectionTitle('Needs a ticker'),
                  for (final r in missing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListRow(
                        icon: assetIcon(r.asset),
                        title: r.name,
                        subtitle: 'Add a ticker to see the live price',
                        chevron: true,
                        onTap: () => openInvestmentForm(context, editing: r),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _unit(InvestmentRecord r, String symbol, double v) =>
    r.asset == 'mutual_funds' ? '₹${v.toStringAsFixed(2)}' : formatPrice(symbol, v);

String _total(InvestmentRecord r, String symbol, double v) =>
    r.asset == 'mutual_funds'
    ? Money(Decimal.parse(v.toStringAsFixed(2)), r.currency).formatShort()
    : formatPrice(symbol, v);

class _PriceRow extends ConsumerWidget {
  const _PriceRow({required this.record});
  final InvestmentRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final finance = context.finance;
    final want = resolveLiveSymbol(record)!;
    final symbol = want.symbol;
    final prices = ref.watch(holdingPricesProvider).value ?? const {};
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final live = liveFor(record, prices);
    final value = live?.value;
    final alert = want.provider == LiveProvider.yahoo
        ? alertLabelFor(symbol, alerts)
        : null;
    final canAlert = want.provider == LiveProvider.yahoo;

    String? delta;
    var up = true;
    if (value != null) {
      final diff = value - record.current.amount.toDouble();
      up = diff >= 0;
      delta =
          '${up ? '+' : '-'}${_total(record, symbol, diff.abs())} vs saved';
    }

    return ListRow(
      icon: assetIcon(record.asset),
      title: record.name,
      subtitle: live == null
          ? '$symbol · price unavailable'
          : '$symbol · ${_unit(record, symbol, live.unitPrice)}',
      chevron: canAlert,
      onTap: canAlert
          ? () => context.push(
              Uri(
                path: priceAlertsPath,
                queryParameters: {'symbol': symbol, 'name': record.name},
              ).toString(),
            )
          : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value != null
                ? _total(record, symbol, value)
                : record.current.formatShort(),
            style: AppTypography.bodyStrong.copyWith(
              color: palette.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (delta != null)
            Text(
              delta,
              style: AppTypography.label.copyWith(
                color: up ? finance.income : finance.expense,
              ),
            )
          else if (live != null)
            Text(
              'Add quantity for value',
              style: AppTypography.label.copyWith(color: palette.muted),
            ),
          if (alert != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TonePill(
                alert.text,
                alert.triggered ? Tones.coral(context) : Tones.butter(context),
                dot: false,
              ),
            )
          else if (canAlert)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 14,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Set alert',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
