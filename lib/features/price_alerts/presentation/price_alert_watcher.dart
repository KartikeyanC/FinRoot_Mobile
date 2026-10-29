import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers/providers.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../application/price_alerts_providers.dart';

/// Checks price alerts every minute while the app is in the foreground, on
/// whichever screen is open. Wraps the app shell; renders [child] unchanged.
/// The hourly background task (`background_sync.dart`) covers the app being
/// closed.
class PriceAlertWatcher extends ConsumerStatefulWidget {
  const PriceAlertWatcher({super.key, required this.child});
  final Widget child;

  static const interval = Duration(seconds: 60);

  @override
  ConsumerState<PriceAlertWatcher> createState() => _PriceAlertWatcherState();
}

class _PriceAlertWatcherState extends ConsumerState<PriceAlertWatcher>
    with WidgetsBindingObserver {
  final _log = AppLog.of('price-alerts');
  Timer? _timer;
  Timer? _kick;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _kick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
      _kick?.cancel();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(PriceAlertWatcher.interval, (_) => _check());
    // A first check shortly after start or resume, not a minute later.
    _kick?.cancel();
    _kick = Timer(const Duration(seconds: 3), _check);
  }

  Future<void> _check() async {
    if (!mounted || _running) return;
    _running = true;
    try {
      if (!ref.read(isSignedInProvider)) return;
      final locked =
          ref.read(menuStatusProvider(FeatureMenu.investments)) ==
          MenuStatus.locked;
      if (locked) return;
      await ref.read(priceAlertCheckProvider)();
    } on Object catch (e) {
      // A viewer cannot record the trigger, or the network is down: try
      // again next minute rather than surfacing an error nobody asked for.
      _log.warning('price alert check failed: ${e.runtimeType}');
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
