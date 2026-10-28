import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/transaction.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/payment_capture_gateway.dart';
import '../domain/detected_payment.dart';

final paymentCaptureGatewayProvider = Provider<PaymentCaptureGateway>(
  (ref) => MethodChannelPaymentCaptureGateway(),
);

class PaymentCaptureState {
  const PaymentCaptureState({
    this.status = const PaymentCaptureStatus(),
    this.payments = const [],
  });

  final PaymentCaptureStatus status;

  /// Waiting for the user to add or ignore, newest first.
  final List<DetectedPayment> payments;
}

final paymentCaptureProvider =
    AsyncNotifierProvider<PaymentCaptureController, PaymentCaptureState>(
      PaymentCaptureController.new,
      name: 'paymentCapture',
    );

/// Detected payments waiting for review, and the on/off switches. The queue
/// is filled by the Android listener while FinRoot is closed, so screens call
/// [refresh] when the app comes back to the foreground.
class PaymentCaptureController extends AsyncNotifier<PaymentCaptureState> {
  PaymentCaptureGateway get _gateway => ref.read(paymentCaptureGatewayProvider);

  @override
  Future<PaymentCaptureState> build() => _load();

  Future<PaymentCaptureState> _load() async {
    final status = await _gateway.status();
    if (!status.supported || !status.enabled) {
      return PaymentCaptureState(status: status);
    }
    final notices = await _gateway.pending();
    final payments = detectPayments(notices);
    // Notices that turned out not to be payments are dropped for good.
    final kept = {for (final p in payments) ...p.noticeIds};
    final junk = [
      for (final n in notices)
        if (!kept.contains(n.id)) n.id,
    ];
    if (junk.isNotEmpty) await _gateway.remove(junk);
    return PaymentCaptureState(status: status, payments: payments);
  }

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  Future<void> setEnabled(bool on) async {
    await _gateway.setEnabled(on);
    if (on) {
      // One system prompt at a time: Notification access first; the pop-up
      // permission is asked for from the screen once access is granted.
      final status = await _gateway.status();
      if (!status.hasAccess) {
        await _gateway.openAccessSettings();
      } else if (status.popupEnabled && !status.canPostNotifications) {
        await _gateway.requestPopupPermission();
      }
    }
    await refresh();
  }

  Future<void> setPopupEnabled(bool on) async {
    await _gateway.setPopupEnabled(on);
    if (on && !(await _gateway.status()).canPostNotifications) {
      await _gateway.requestPopupPermission();
    }
    await refresh();
  }

  Future<void> requestPopupPermission() => _gateway.requestPopupPermission();

  Future<void> setSmsEnabled(bool on) async {
    await _gateway.setSmsEnabled(on);
    await refresh();
  }

  Future<void> openAccessSettings() => _gateway.openAccessSettings();

  /// Added to the ledger, or ignored — either way it leaves the queue.
  Future<void> resolve(DetectedPayment p) async {
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        PaymentCaptureState(
          status: current.status,
          payments: [
            for (final q in current.payments)
              if (q.id != p.id) q,
          ],
        ),
      );
    }
    await _gateway.remove(p.noticeIds);
  }
}

/// Recent ledger rows, to flag a detected payment that looks already added.
final recentLedgerForMatchingProvider = StreamProvider<List<TransactionEntity>>(
  (ref) {
    final tenantId = ref.watch(currentTenantIdProvider);
    if (tenantId == null) return Stream.value(const []);
    return ref
        .watch(transactionsRepositoryProvider)
        .watchRecent(tenantId, limit: 200);
  },
);
