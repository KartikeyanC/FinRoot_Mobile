import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/detected_payment.dart';

/// Where payment detection stands on this device.
class PaymentCaptureStatus {
  const PaymentCaptureStatus({
    this.supported = false,
    this.enabled = false,
    this.smsEnabled = false,
    this.hasAccess = false,
  });

  /// Android only — iOS gives apps no access to other apps' notifications.
  final bool supported;

  /// The user turned detection on in FinRoot.
  final bool enabled;

  /// Bank SMS alerts are included too.
  final bool smsEnabled;

  /// Android's "Notification access" is granted to FinRoot.
  final bool hasAccess;

  bool get active => supported && enabled && hasAccess;
}

/// The Android side lives in PaymentListenerService.kt / MainActivity.kt.
abstract interface class PaymentCaptureGateway {
  Future<PaymentCaptureStatus> status();
  Future<void> setEnabled(bool on);
  Future<void> setSmsEnabled(bool on);
  Future<void> openAccessSettings();
  Future<List<PaymentNotice>> pending();
  Future<void> remove(List<String> noticeIds);
}

class MethodChannelPaymentCaptureGateway implements PaymentCaptureGateway {
  static const _channel = MethodChannel('finroot/payment_capture');

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<PaymentCaptureStatus> status() async {
    if (!_supported) return const PaymentCaptureStatus();
    final m = await _channel.invokeMapMethod<String, Object?>('status') ?? {};
    return PaymentCaptureStatus(
      supported: true,
      enabled: m['enabled'] == true,
      smsEnabled: m['smsEnabled'] == true,
      hasAccess: m['hasAccess'] == true,
    );
  }

  @override
  Future<void> setEnabled(bool on) => _channel.invokeMethod('setEnabled', on);

  @override
  Future<void> setSmsEnabled(bool on) =>
      _channel.invokeMethod('setSmsEnabled', on);

  @override
  Future<void> openAccessSettings() =>
      _channel.invokeMethod('openAccessSettings');

  @override
  Future<List<PaymentNotice>> pending() async {
    if (!_supported) return const [];
    final raw = await _channel.invokeMethod<String>('pending') ?? '[]';
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(PaymentNotice.fromJson)
        .toList();
  }

  @override
  Future<void> remove(List<String> noticeIds) =>
      _channel.invokeMethod('remove', noticeIds);
}
