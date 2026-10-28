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
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        color: scheme.secondaryContainer,
        onTap: () => context.push(DetectedPaymentsBanner.route),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: scheme.onSecondaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 payment to review'
                        : '$count payments to review',
                    style: t.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    'Detected from your payment apps — add in one tap',
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }
}
