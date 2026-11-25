import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/widget_figures.dart';

/// A home-screen widget button that opened (or reached) FinRoot.
enum WidgetAction {
  /// Scan a shop's UPI QR and pay it.
  scanPay,

  /// Photograph a bill.
  scanBill,
}

/// The Android home-screen widget (`FinRootWidget.kt`, channel
/// "finroot/home_widget"). The widget's third button, Add, opens the floating
/// Quick Add directly and never comes through here.
abstract interface class HomeWidgetGateway {
  /// False off Android (and in tests), where there is no widget to feed.
  bool get supported;

  /// Shows [figures] on every FinRoot widget.
  Future<void> show(WidgetFigures figures);

  /// Signed out: the widget shows dashes, not the last person's spend.
  Future<void> clear();

  /// The widget button that launched FinRoot, once (then null).
  Future<WidgetAction?> takeLaunchAction();

  /// Widget buttons tapped while FinRoot was already running.
  Stream<WidgetAction> get actions;
}

class MethodChannelHomeWidgetGateway implements HomeWidgetGateway {
  MethodChannelHomeWidgetGateway() {
    if (supported) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'action') return;
        final a = _parse(call.arguments);
        if (a != null) _actions.add(a);
      });
    }
  }

  static const _channel = MethodChannel('finroot/home_widget');
  final _actions = StreamController<WidgetAction>.broadcast();

  // dart:io, not defaultTargetPlatform: widget tests run as "android" on the
  // host, and there is no widget host there to talk to.
  @override
  bool get supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> show(WidgetFigures figures) async {
    if (supported) await _channel.invokeMethod('update', figures.toMap());
  }

  @override
  Future<void> clear() async {
    if (supported) await _channel.invokeMethod('clear');
  }

  @override
  Future<WidgetAction?> takeLaunchAction() async => supported
      ? _parse(await _channel.invokeMethod<String>('takeLaunchAction'))
      : null;

  @override
  Stream<WidgetAction> get actions => _actions.stream;

  static WidgetAction? _parse(Object? raw) => switch (raw) {
    'scanPay' => WidgetAction.scanPay,
    'scanBill' => WidgetAction.scanBill,
    _ => null,
  };
}
