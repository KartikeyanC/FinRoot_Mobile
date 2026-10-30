import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../application/payment_capture_controller.dart';

/// "3 payments to review" on Home — shown only while detection is on and
/// something is waiting.
class DetectedPaymentsBanner extends ConsumerStatefulWidget {
  const DetectedPaymentsBanner({super.key});

  static const route = '/detected-payments';

  @override
  ConsumerState<DetectedPaymentsBanner> createState() =>
      _DetectedPaymentsBannerState();
}

class _DetectedPaymentsBannerState
    extends ConsumerState<DetectedPaymentsBanner> {
  // New payments land while FinRoot is in the background.
  late final _lifecycle = AppLifecycleListener(
    onResume: () => ref.read(paymentCaptureProvider.notifier).refresh(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentCaptureProvider).value;
    final count = state?.payments.length ?? 0;
    if (state == null || !state.status.active || count == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: InfoPill(
        icon: Icons.bolt_rounded,
        text: count == 1 ? '1 payment to review' : '$count payments to review',
        detail: 'Add in one tap',
        onTap: () => context.push(DetectedPaymentsBanner.route),
      ),
    );
  }
}
