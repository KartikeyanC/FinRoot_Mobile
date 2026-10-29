import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../design/design.dart';
import '../../investments/data/live_price_gateway.dart';
import '../../investments/domain/live_price.dart';
import '../../notifications/data/notification_service.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/price_alerts_providers.dart';
import '../domain/price_alert.dart';

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
    // Keep the shown prices fresh while this screen is open.
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => ref.invalidate(alertPricesProvider),
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Price alerts')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openAddSheet(context),
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Alert'),
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
          data: (list) => list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: AppSpacing.huge),
                    EmptyView(
                      icon: Icons.notifications_active_outlined,
                      title: 'No price alerts yet',
                      message:
                          'Pick a stock you like but find too expensive today, '
                          'set the price you would be happy to pay, and you '
                          'will get a notification when it reaches it.',
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenGutter,
                    AppSpacing.lg,
                    AppSpacing.screenGutter,
                    AppSpacing.huge,
                  ),
                  children: [
                    Text(
                      'Checked every minute while FinRoot is open, and about '
                      'once an hour in the background.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final a in [
                      ...list.where((a) => a.isActive),
                      ...list.where((a) => !a.isActive),
                    ])
                      _AlertTile(
                        alert: a,
                        price: prices[a.priceKey],
                        canWrite: canWrite,
                      ),
                  ],
                ),
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
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final finance = context.finance;
    final active = alert.isActive;
    final gap = price == null ? double.nan : distanceToTarget(alert, price!);

    final String trailingTop;
    final String trailingBottom;
    if (active) {
      trailingTop = price == null ? '…' : formatPrice(alert.symbol, price!);
      trailingBottom = price == null
          ? 'Waiting for a price'
          : (gap.isFinite && gap > 0
                ? '${gap.toStringAsFixed(1)}% to go'
                : 'At target');
    } else {
      trailingTop = formatPrice(
        alert.symbol,
        alert.triggeredPrice ?? alert.target,
      );
      trailingBottom = 'Triggered';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: active
                  ? scheme.secondaryContainer
                  : finance.income.withValues(alpha: 0.15),
              child: Icon(
                active
                    ? Icons.notifications_active_outlined
                    : Icons.check_circle_outline,
                size: 20,
                color: active ? scheme.onSecondaryContainer : finance.income,
              ),
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
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${alert.symbol} · ${describeAlert(alert).replaceFirst('${alert.name} ', '')}',
                    maxLines: 2,
                    style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  trailingBottom,
                  style: tt.labelSmall?.copyWith(
                    color: active ? scheme.onSurfaceVariant : finance.income,
                  ),
                ),
              ],
            ),
            if (canWrite)
              PopupMenuButton<String>(
                onSelected: (v) => _act(context, ref, v),
                itemBuilder: (_) => [
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
    final tt = Theme.of(context).textTheme;
    final sym = normaliseSymbol(_symbol.text);
    final cur = sym.isEmpty ? '' : currencySymbol(sym);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        0,
        AppSpacing.screenGutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New price alert', style: tt.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Use the Yahoo ticker: RELIANCE.NS or ITC.NS for NSE, AAPL for US.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _symbol,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Ticker',
              hintText: 'ITC.NS',
              helperText: _looking
                  ? 'Looking up the price…'
                  : (_now != null
                        ? 'Now ${formatPrice(sym, _now!)}'
                        : (sym.length >= 2 ? 'Tap the search icon for the live price' : null)),
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
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'ITC Limited',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<AlertDirection>(
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
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price',
              prefixText: cur.isEmpty ? null : '$cur ',
              helperText: _direction == AlertDirection.below
                  ? 'Alert when the price is at or below this (a buy level)'
                  : 'Alert when the price is at or above this',
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Create alert'),
          ),
        ],
      ),
    );
  }
}
