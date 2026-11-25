import 'package:flutter/services.dart';

import '../domain/upi_qr.dart';

/// What came of opening the QR scanner.
sealed class QrScan {
  const QrScan();
}

class QrScanned extends QrScan {
  const QrScanned(this.code);
  final String code;
}

/// The person closed the scanner.
class QrCancelled extends QrScan {
  const QrCancelled();
}

/// The scanner couldn't run. [downloading]: Play services is still fetching
/// it (first use on this phone); worth trying again in a minute.
class QrUnavailable extends QrScan {
  const QrUnavailable({this.downloading = false});
  final bool downloading;
}

/// What came of handing the payment to a UPI app.
sealed class PayResult {
  const PayResult();
}

/// No UPI app on the phone can take a upi:// link.
class NoUpiApp extends PayResult {
  const NoUpiApp();
}

class PayAnswered extends PayResult {
  const PayAnswered(this.outcome);
  final UpiOutcome outcome;
}

/// Android side: `UpiBridge.kt` (channel "finroot/upi").
abstract interface class UpiGateway {
  Future<QrScan> scanQr();
  Future<PayResult> pay(Uri upiLink);
}

class MethodChannelUpiGateway implements UpiGateway {
  static const _channel = MethodChannel('finroot/upi');

  @override
  Future<QrScan> scanQr() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('scanQr') ?? {};
      final code = m['code'];
      if (code is String && code.isNotEmpty) return QrScanned(code);
      if (m['cancelled'] == true) return const QrCancelled();
      return QrUnavailable(downloading: m['error'] == 'downloading');
    } on PlatformException {
      return const QrUnavailable();
    } on MissingPluginException {
      return const QrUnavailable();
    }
  }

  @override
  Future<PayResult> pay(Uri upiLink) async {
    final m =
        await _channel.invokeMapMethod<String, Object?>(
          'pay',
          upiLink.toString(),
        ) ??
        {};
    if (m['noApp'] == true) return const NoUpiApp();
    return PayAnswered(parseUpiResponse(m['response'] as String?));
  }
}
