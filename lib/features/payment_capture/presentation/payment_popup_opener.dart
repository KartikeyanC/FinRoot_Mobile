import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/payment_capture_controller.dart';
import '../domain/shared_text.dart';
import 'detected_payments_banner.dart';
import 'detected_payments_screen.dart';

/// Sits in the signed-in app shell and turns a tapped "₹500 paid — add to
/// FinRoot?" pop-up into Quick Add for that payment — whether the tap
/// launched FinRoot or reached it while it was already open. A bank SMS
/// shared to FinRoot ("Add to FinRoot" in the Share menu) opens Quick Add
/// the same way.
class PaymentPopupOpener extends ConsumerStatefulWidget {
  const PaymentPopupOpener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<PaymentPopupOpener> createState() => _PaymentPopupOpenerState();
}

class _PaymentPopupOpenerState extends ConsumerState<PaymentPopupOpener> {
  StreamSubscription<String>? _sub;
  StreamSubscription<String>? _shared;

  @override
  void initState() {
    super.initState();
    final gateway = ref.read(paymentCaptureGatewayProvider);
    _sub = gateway.openRequests.listen(_open);
    _shared = gateway.sharedTexts.listen(_openShared);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = await gateway.takeLaunchNotice().catchError((_) => null);
      if (id != null) _open(id);
      final text = await gateway.takeSharedText().catchError((_) => null);
      if (text != null) await _openShared(text);
    });
  }

  Future<void> _openShared(String text) async {
    if (!mounted) return;
    final payment = paymentFromSharedText(text, now: DateTime.now());
    if (payment == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'No payment found in that message. Share a bank debit or '
            'credit SMS, or add it with Quick Add.',
          ),
        ),
      );
      return;
    }
    await openQuickAddForPayment(context, payment);
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
    _shared?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
