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

/// Route of the Price alerts tab of Investments (also what a tapped alert
/// notification opens).
const priceAlertsPath = '/price-alerts';

/// The "+ Alert" button that opens the new-alert sheet.
class PriceAlertFab extends ConsumerWidget {
  const PriceAlertFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AddFab(
    label: 'Alert',
    icon: Icons.add_alert_outlined,
    onPressed: () => openPriceAlertSheet(context, ref),
  );
}

/// Opens the new-alert sheet, pre-filled when [symbol] is given.
Future<void> openPriceAlertSheet(
  BuildContext context,
  WidgetRef ref, {
  String? symbol,
  String? name,
}) async {
  // Ask now, from a tap: Android 13+ needs the permission to post alerts.
  unawaited(ref.read(notificationServiceProvider).requestPermission());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddAlertSheet(symbol: symbol, name: name),
  );
}

/// Price alerts: decide the price you would buy at, and get a notification
/// when the stock reaches it. The same list as the web dashboard. No page
/// chrome, so it can sit inside the Investments screen as a tab.
class PriceAlertsView extends ConsumerStatefulWidget {
  const PriceAlertsView({super.key, this.initialSymbol, this.initialName});

  /// When set (from the Live prices list) the add-alert sheet opens
  /// pre-filled for this symbol.
  final String? initialSymbol;
  final String? initialName;

  @override
  ConsumerState<PriceAlertsView> createState() => _PriceAlertsViewState();
}

class _PriceAlertsViewState extends ConsumerState<PriceAlertsView> {
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
    final sym = widget.initialSymbol;
    if (sym != null && sym.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            openPriceAlertSheet(
              context,
              ref,
              symbol: sym,
              name: widget.initialName,
            ),
          );
        }
      });
    }
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

    return RefreshIndicator(
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
                      onPressed: () => openPriceAlertSheet(context, ref),
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
                  const SizedBox(height: 6),
                  TonePill(pillLabel, pillTone, dot: false),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              trailingTop,
              style: AppTypography.bodyStrong.copyWith(
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
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
  const _AddAlertSheet({this.symbol, this.name});
  final String? symbol;
  final String? name;

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
  void initState() {
    super.initState();
    _symbol.text = widget.symbol ?? '';
    _name.text = widget.name ?? '';
    if (_symbol.text.isNotEmpty) unawaited(_lookUp());
  }

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
              helperMaxLines: 3,
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
              helperMaxLines: 3,
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

/// The alarm chip in the first row of a holding card, next to the average
/// price — both are per-share prices, so "Avg ₹410  ⏰ ₹400" reads at a
/// glance. Just the alarm and the amount: watching in the accent colour,
/// fired in green. None: a quiet "Alert" that sets one. Without a ticker it asks for one first
/// ([onNeedTicker]), which replaces the old "add a ticker" line.
class HoldingAlertChip extends ConsumerWidget {
  const HoldingAlertChip({
    super.key,
    required this.symbol,
    required this.name,
    required this.canWrite,
    this.onNeedTicker,
  });

  final String? symbol;
  final String name;
  final bool canWrite;
  final VoidCallback? onNeedTicker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sym = symbol;
    final alerts = ref.watch(priceAlertsProvider).value ?? const [];
    final label = sym == null ? null : alertLabelFor(sym, alerts);
    if (label == null && !canWrite) return const SizedBox.shrink();

    final palette = context.palette;
    final Tone? tone = label == null
        ? null
        : (label.triggered ? Tones.mint(context) : Tones.accent(context));
    final fg = tone?.fg ?? palette.muted;

    final VoidCallback? onTap = sym == null
        ? onNeedTicker
        : () => openHoldingAlerts(context, ref, symbol: sym, name: name);

    return Semantics(
      button: true,
      label: label == null ? 'Set a price alert' : 'Price alert ${label.text}',
      child: GestureDetector(
        key: const Key('holding-alert-chip'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // A bigger hit area than the chip itself.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: tone?.bg,
              borderRadius: BorderRadius.circular(999),
              border: tone == null ? Border.all(color: palette.line) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  label == null
                      ? Icons.alarm_add_rounded
                      : (label.triggered
                            ? Icons.alarm_on_rounded
                            : Icons.alarm_rounded),
                  size: 13,
                  color: fg,
                ),
                const SizedBox(width: 3),
                Text(
                  label == null ? 'Alert' : _amountOnly(label.text),
                  style: AppTypography.label.copyWith(
                    color: fg,
                    fontSize: 11.5,
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

/// A holding's alerts, from its chip or its menu: the new-alert sheet when
/// the stock has none yet, else the list of its alerts.
Future<void> openHoldingAlerts(
  BuildContext context,
  WidgetRef ref, {
  required String symbol,
  required String name,
}) {
  final alerts = ref.read(priceAlertsProvider).value ?? const [];
  if (!alerts.any((a) => a.symbol == symbol)) {
    return openPriceAlertSheet(context, ref, symbol: symbol, name: name);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HoldingAlertsSheet(symbol: symbol, name: name),
  );
}

/// The alerts of one stock, opened from its holding card: each one can be
/// re-armed or deleted, and another added, without leaving Investments.
class _HoldingAlertsSheet extends ConsumerWidget {
  const _HoldingAlertsSheet({required this.symbol, required this.name});
  final String symbol;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final prices = ref.watch(alertPricesProvider).value ?? const {};
    final mine = (ref.watch(priceAlertsProvider).value ?? const [])
        .where((a) => a.symbol == symbol)
        .toList()
      ..sort((x, y) => (x.isActive ? 0 : 1).compareTo(y.isActive ? 0 : 1));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Price alerts · $name',
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            if (mine.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'No alerts left for $symbol.',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final a in mine)
                    _AlertTile(
                      alert: a,
                      price: prices[a.priceKey],
                      canWrite: canWrite,
                    ),
                ],
              ),
            ),
            if (canWrite)
              FilledButton.icon(
                icon: const Icon(Icons.add_alert_outlined),
                label: const Text('Add another alert'),
                onPressed: () =>
                    openPriceAlertSheet(context, ref, symbol: symbol, name: name),
              ),
          ],
        ),
      ),
    );
  }
}

/// "↓ ₹400 +1" → "₹400 +1", "Hit ₹402" → "₹402": the chip shows the alarm
/// icon and the amount only.
String _amountOnly(String label) =>
    label.replaceFirst(RegExp(r'^(↓|↑|Hit)\s*'), '');
