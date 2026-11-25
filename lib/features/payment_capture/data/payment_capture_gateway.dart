import 'dart:async';
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
    this.popupEnabled = true,
    this.canPostNotifications = true,
    this.hasAccess = false,
    this.included = true,
  });

  /// Android only — iOS gives apps no access to other apps' notifications.
  final bool supported;

  /// The user turned detection on in FinRoot.
  final bool enabled;

  /// Bank SMS alerts are included too.
  final bool smsEnabled;

  /// Pop up a "₹500 paid — add to FinRoot?" notification the moment a
  /// payment is detected.
  final bool popupEnabled;

  /// Android 13+ lets FinRoot post notifications at all.
  final bool canPostNotifications;

  /// Android's "Notification access" is granted to FinRoot.
  final bool hasAccess;

  /// This build carries payment detection. Side-loaded release builds leave
  /// it out: Play Protect blocks apps installed outside the Play Store that
  /// ask for notification access.
  final bool included;

  bool get active => supported && included && enabled && hasAccess;
}

/// The Android side lives in PaymentListenerService.kt / MainActivity.kt.
abstract interface class PaymentCaptureGateway {
  Future<PaymentCaptureStatus> status();
  Future<void> setEnabled(bool on);
  Future<void> setSmsEnabled(bool on);
  Future<void> setPopupEnabled(bool on);

  /// Asks Android 13+ for permission to post the pop-up.
  Future<void> requestPopupPermission();
  Future<void> openAccessSettings();
  Future<List<PaymentNotice>> pending();
  Future<void> remove(List<String> noticeIds);

  /// The notice whose pop-up launched FinRoot, once (then null).
  Future<String?> takeLaunchNotice();

  /// Notices whose pop-up was tapped while FinRoot was already running.
  Stream<String> get openRequests;

  /// Text shared to FinRoot that launched it (Messages → Share → "Add to
  /// FinRoot"), once (then null).
  Future<String?> takeSharedText();

  /// Text shared to FinRoot while it was already running.
  Stream<String> get sharedTexts;
}

class MethodChannelPaymentCaptureGateway implements PaymentCaptureGateway {
  MethodChannelPaymentCaptureGateway() {
    if (_supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'openNotice') _opens.add(call.arguments as String);
        if (call.method == 'sharedText') _shared.add(call.arguments as String);
      });
    }
  }

  static const _channel = MethodChannel('finroot/payment_capture');
  final _opens = StreamController<String>.broadcast();
  final _shared = StreamController<String>.broadcast();

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
      popupEnabled: m['popupEnabled'] != false,
      canPostNotifications: m['canPostNotifications'] != false,
      hasAccess: m['hasAccess'] == true,
      included: m['included'] != false,
    );
  }

  @override
  Future<void> setEnabled(bool on) => _channel.invokeMethod('setEnabled', on);

  @override
  Future<void> setSmsEnabled(bool on) =>
      _channel.invokeMethod('setSmsEnabled', on);

  @override
  Future<void> setPopupEnabled(bool on) =>
      _channel.invokeMethod('setPopupEnabled', on);

  @override
  Future<void> requestPopupPermission() =>
      _channel.invokeMethod('requestPopupPermission');

  @override
  Future<String?> takeLaunchNotice() async =>
      _supported ? _channel.invokeMethod<String>('takeLaunchNotice') : null;

  @override
  Stream<String> get openRequests => _opens.stream;

  @override
  Future<String?> takeSharedText() async =>
      _supported ? _channel.invokeMethod<String>('takeSharedText') : null;

  @override
  Stream<String> get sharedTexts => _shared.stream;

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
