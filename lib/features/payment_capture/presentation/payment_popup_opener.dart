import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/payment_capture_controller.dart';
import 'detected_payments_banner.dart';

/// Sits in the signed-in app shell and turns a tapped "₹500 paid — add to
/// FinRoot?" pop-up into Quick Add for that payment — whether the tap
/// launched FinRoot or reached it while it was already open.
class PaymentPopupOpener extends ConsumerStatefulWidget {
  const PaymentPopupOpener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PaymentPopupOpener> createState() => _PaymentPopupOpenerState();
}

class _PaymentPopupOpenerState extends ConsumerState<PaymentPopupOpener> {
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    final gateway = ref.read(paymentCaptureGatewayProvider);
    _sub = gateway.openRequests.listen(_open);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await gateway.takeLaunchNotice().catchError((_) => null);
      if (id != null) _open(id);
    });
  }

  void _open(String noticeId) {
    if (!mounted) return;
    context.push(
      Uri(
        path: DetectedPaymentsBanner.route,
        queryParameters: {'add': noticeId},
      ).toString(),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
