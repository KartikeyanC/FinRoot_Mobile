import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/constants.dart';
import '../../bill_scan/application/bill_scan_controller.dart';
import '../../menus/application/menu_providers.dart';
import '../../upi_pay/presentation/scan_pay_screen.dart';
import '../application/home_widget_providers.dart';
import '../data/home_widget_gateway.dart';
import '../domain/widget_figures.dart';

/// Sits in the signed-in app shell and connects FinRoot to its home-screen
/// widget: keeps today's and this month's spend on it current, and turns its
/// Scan & pay and Scan bill buttons into the right screen — whether the tap
/// launched FinRoot or reached it while it was open.
///
/// Inert where there is no widget (off Android, and in tests).
class HomeWidgetBridge extends ConsumerStatefulWidget {
  const HomeWidgetBridge({super.key, required this.child});
  final Widget child;

  static const billScanRoute = '/bill-scan';

  @override
  ConsumerState<HomeWidgetBridge> createState() => _HomeWidgetBridgeState();
}

class _HomeWidgetBridgeState extends ConsumerState<HomeWidgetBridge>
    with WidgetsBindingObserver {
  StreamSubscription<WidgetAction>? _sub;
  WidgetFigures? _shown;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    final gateway = ref.read(homeWidgetGatewayProvider);
    if (!gateway.supported) return;
    _active = true;
    WidgetsBinding.instance.addObserver(this);
    _sub = gateway.actions.listen(_handle);
    ref.listenManual<WidgetFigures?>(
      widgetFiguresProvider,
      (_, next) => _show(next),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await gateway.takeLaunchAction().catchError((_) => null);
      if (action != null) _handle(action);
    });
  }

  Future<void> _show(WidgetFigures? figures) async {
    if (figures == null || figures == _shown) return;
    _shown = figures;
    try {
      await ref.read(homeWidgetGatewayProvider).show(figures);
    } on Object {
      _shown = null; // try again with the next change
    }
  }

  // Back from the background, maybe on a new day: work the figures out again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(widgetFiguresProvider);
    }
  }

  void _handle(WidgetAction action) {
    if (!mounted) return;
    switch (action) {
      case WidgetAction.scanPay:
        unawaited(context.push(ScanPayScreen.route));
      case WidgetAction.scanBill:
        unawaited(context.push(HomeWidgetBridge.billScanRoute));
        // Straight to the camera, as the button says — unless the plan has
        // no Bill scan, when the screen explains that instead.
        final locked =
            ref.read(menuStatusProvider(FeatureMenu.billScan)) ==
            MenuStatus.locked;
        if (!locked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(
                ref
                    .read(billScanControllerProvider.notifier)
                    .captureFromCamera(),
              );
            }
          });
        }
    }
  }

  @override
  void dispose() {
    if (_active) WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
