import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../investments/data/live_price_gateway.dart';
import '../../investments/domain/live_price.dart';
import '../../notifications/data/notification_service.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/price_alerts_providers.dart';
import '../domain/price_alert.dart';

/// Route of the Price alerts screen (also what a tapped alert notification opens).
const priceAlertsPath = '/price-alerts';

/// Price alerts: decide the price you would buy at, and get a notification
/// when the stock reaches it. The same list as the web dashboard.
class PriceAlertsScreen extends ConsumerStatefulWidget {
  const PriceAlertsScreen({super.key});

  @override
  ConsumerState<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends ConsumerState<PriceAlertsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Keep the list and prices fresh while this screen is open: alerts
    // added, fired or deleted on the laptop show up within a minute.
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.invalidate(priceAlertsProvider);
      ref.invalidate(alertPricesProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(priceAlertsProvider);
    final prices = ref.watch(alertPricesProvider).value ?? const {};
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final hasAlerts = alerts.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Price alerts',
      padBody: false,
      floatingActionButton: canWrite && hasAlerts
          ? AddFab(
              label: 'Alert',
              icon: Icons.add_alert_outlined,
              onPressed: () => _openAddSheet(context),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(priceAlertsProvider);
          ref.invalidate(alertPricesProvider);
        },
        child: alerts.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            e,
            onRetry: () => ref.invalidate(priceAlertsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return EmptyView(
                icon: Icons.notifications_active_outlined,
                title: 'No price alerts yet',
                message:
                    'Pick a stock you like but find too expensive today, '
                    'set the price you would be happy to pay, and you '
                    'will get a notification when it reaches it.',
                action: canWrite
                    ? FilledButton(
                        onPressed: () => _openAddSheet(context),
                        child: const Text('Add an alert'),
                      )
                    : null,
              );
            }
            final watching = list.where((a) => a.isActive).toList();
            final triggered = list.where((a) => !a.isActive).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                96,
              ),
              children: [
                StatStrip([
                  Stat('${watching.length}', 'Watching'),
                  Stat(
                    '${triggered.length}',
                    'Triggered',
                    color: triggered.isEmpty ? null : context.finance.income,
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                const InfoPill(
                  icon: Icons.schedule_rounded,
                  text: 'Checked every minute while open',
                ),
                if (watching.isNotEmpty) const SectionTitle('Watching'),
                for (final a in watching)
                  _AlertTile(
                    alert: a,
                    price: prices[a.priceKey],
                    canWrite: canWrite,
                  ),
                if (triggered.isNotEmpty) const SectionTitle('Triggered'),
                for (final a in triggered)
                  _AlertTile(
                    alert: a,
                    price: prices[a.priceKey],
                    canWrite: canWrite,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    // Ask now, from a tap: Android 13+ needs the permission to post alerts.
    unawaited(ref.read(notificationServiceProvider).requestPermission());
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddAlertSheet(),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  const _AlertTile({
    required this.alert,
    required this.price,
    required this.canWrite,
  });
  final PriceAlert alert;
  final double? price;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final active = alert.isActive;
    final gap = price == null ? double.nan : distanceToTarget(alert, price!);

    final String trailingTop;
    final String pillLabel;
    final Tone pillTone;
    if (active) {
      trailingTop = price == null ? '…' : formatPrice(alert.symbol, price!);
      if (price == null) {
        pillLabel = 'Waiting for a price';
        pillTone = Tones.accent(context);
      } else if (gap.isFinite && gap > 0) {
        pillLabel = '${gap.toStringAsFixed(1)}% to go';
        pillTone = Tones.sky(context);
      } else {
        pillLabel = 'At target';
        pillTone = Tones.mint(context);
      }
    } else {
      trailingTop = formatPrice(
        alert.symbol,
        alert.triggeredPrice ?? alert.target,
      );
      pillLabel = 'Triggered';
      pillTone = Tones.mint(context);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            ToneTile(
              icon: active
                  ? Icons.notifications_active_outlined
                  : Icons.check_circle_outline,
              tone: active ? Tones.accent(context) : Tones.mint(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${alert.symbol} · ${describeAlert(alert).replaceFirst('${alert.name} ', '')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  trailingTop,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                TonePill(pillLabel, pillTone, dot: false),
              ],
            ),
            if (canWrite)
              RowMenu(
                onSelected: (v) => _act(context, ref, v),
                items: [
                  if (!active)
                    const PopupMenuItem(
                      value: 'rearm',
                      child: Text('Watch again'),
                    ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(priceAlertsControllerProvider);
    try {
      if (action == 'rearm') {
        await controller.rearm(alert.id);
        messenger.showSnackBar(
          SnackBar(content: Text('Watching ${alert.symbol} again')),
        );
      } else {
        await controller.remove(alert.id);
        messenger.showSnackBar(const SnackBar(content: Text('Alert deleted')));
      }
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

class _AddAlertSheet extends ConsumerStatefulWidget {
  const _AddAlertSheet();

  @override
  ConsumerState<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends ConsumerState<_AddAlertSheet> {
  final _symbol = TextEditingController();
  final _name = TextEditingController();
  final _target = TextEditingController();
  var _direction = AlertDirection.below;
  String? _error;
  double? _now;
  bool _looking = false;
  bool _saving = false;

  @override
  void dispose() {
    _symbol.dispose();
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final sym = normaliseSymbol(_symbol.text);
    if (sym.length < 2) return;
    setState(() {
      _looking = true;
      _now = null;
    });
    final prices = await ref
        .read(livePriceGatewayProvider)
        .fetch([LiveWant(LiveProvider.yahoo, sym)]);
    if (!mounted) return;
    setState(() {
      _looking = false;
      _now = prices['yahoo:$sym'];
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final problem = await ref
          .read(priceAlertsControllerProvider)
          .add(
            symbol: _symbol.text,
            name: _name.text,
            target: _target.text,
            direction: _direction,
          );
      if (!mounted) return;
      if (problem != null) {
        setState(() {
          _error = problem;
          _saving = false;
        });
        return;
      }
      Navigator.of(context).pop();
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _error = f.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = normaliseSymbol(_symbol.text);
    final cur = sym.isEmpty ? '' : currencySymbol(sym);

    return SheetFrame(
      title: 'New price alert',
      subtitle: 'Use the Yahoo ticker: RELIANCE.NS or ITC.NS for NSE, AAPL for US.',
      primaryLabel: _saving ? 'Saving…' : 'Create alert',
      onPrimary: _save,
      busy: _saving,
      error: _error,
      children: [
        LabeledField(
          label: 'Ticker',
          child: TextField(
            controller: _symbol,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'ITC.NS',
              helperText: _looking
                  ? 'Looking up the price…'
                  : (_now != null
                        ? 'Now ${formatPrice(sym, _now!)}'
                        : (sym.length >= 2
                              ? 'Tap the search icon for the live price'
                              : null)),
              suffixIcon: IconButton(
                tooltip: 'Look up the live price',
                icon: const Icon(Icons.search),
                onPressed: _lookUp,
              ),
            ),
            onChanged: (_) => setState(() {
              _now = null;
              _error = null;
            }),
            onSubmitted: (_) => _lookUp(),
          ),
        ),
        LabeledField(
          label: 'Name (optional)',
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'ITC Limited'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: SegmentedButton<AlertDirection>(
            segments: const [
              ButtonSegment(
                value: AlertDirection.below,
                label: Text('Falls to'),
                icon: Icon(Icons.south),
              ),
              ButtonSegment(
                value: AlertDirection.above,
                label: Text('Rises to'),
                icon: Icon(Icons.north),
              ),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
        ),
        LabeledField(
          label: 'Price',
          child: TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: cur.isEmpty ? null : '$cur ',
              helperText: _direction == AlertDirection.below
                  ? 'Alert when the price is at or below this (a buy level)'
                  : 'Alert when the price is at or above this',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
      ],
    );
  }
}
