import 'package:decimal/decimal.dart';

/// A UPI payment QR, read: who to pay and, for a fixed-price QR, how much.
///
/// UPI QRs carry a `upi://pay?pa=…&pn=…` link (NPCI's deep-link spec):
/// `pa` the payee's UPI id, `pn` their name, `am` a fixed amount, `tn` a note,
/// plus merchant fields (`mc`, `tr`, `sign`…) FinRoot passes along untouched.
class UpiPayee {
  const UpiPayee({
    required this.vpa,
    required this.params,
    this.query = '',
    this.name,
    this.amount,
    this.note,
  });

  /// The UPI id, e.g. "shop@okaxis".
  final String vpa;
  final String? name;

  /// Set when the QR fixes the amount; it can't be changed then.
  final Decimal? amount;
  final String? note;

  /// Every field of the QR, keys lower-cased, in their original order.
  final Map<String, String> params;

  /// The QR's fields exactly as printed (the text after "?"). The UPI app
  /// gets these back untouched: a re-encoded field ("+" turned into a space,
  /// "@" into "%40") no longer matches what the shop's bank issued, and the
  /// payment is declined.
  final String query;

  String get displayName => name ?? vpa;
  bool get fixedAmount => amount != null;

  /// A bank-signed QR (`sign`): any field FinRoot added would break it.
  bool get signed => (params['sign'] ?? '').isNotEmpty;
}

final _vpa = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z][a-zA-Z0-9.\-]{1,64}$');

/// The payee in a scanned QR, or null when it isn't a UPI payment QR (a
/// website, a Wi-Fi code, a UPI id with no `pa`…). Lenient about case and
/// about names that weren't escaped ("pn=Sri Sai Stores").
UpiPayee? parseUpiQr(String raw) {
  final text = raw.trim();
  final q = text.indexOf('?');
  if (q < 0) return null;
  final head = text
      .substring(0, q)
      .toLowerCase()
      .replaceAll(RegExp(r'/+$'), '');
  if (head != 'upi://pay') return null;

  final query = text.substring(q + 1);
  final params = <String, String>{};
  for (final part in query.split('&')) {
    if (part.isEmpty) continue;
    final eq = part.indexOf('=');
    final key = (eq < 0 ? part : part.substring(0, eq)).trim().toLowerCase();
    if (key.isEmpty) continue;
    params[key] = eq < 0 ? '' : _decode(part.substring(eq + 1)).trim();
  }

  final vpa = params['pa'] ?? '';
  if (!_vpa.hasMatch(vpa)) return null;
  final am = Decimal.tryParse(params['am'] ?? '');
  String? orNull(String? s) => (s == null || s.isEmpty) ? null : s;
  return UpiPayee(
    vpa: vpa,
    name: orNull(params['pn']),
    amount: am != null && am > Decimal.zero ? am : null,
    note: orNull(params['tn']),
    params: params,
    query: query,
  );
}

String _decode(String s) {
  try {
    return Uri.decodeQueryComponent(s);
  } on Object {
    return s; // a stray "%" in a shop's name: keep it as written
  }
}

/// The link handed to the UPI app: the QR's own fields byte for byte, as the
/// UPI app would read them scanning the QR itself, plus only what's missing —
/// the amount the person typed (unless the QR fixed one) and, on a QR the
/// bank didn't sign, INR and their note when the QR had none.
Uri upiPayUri(UpiPayee payee, {required Decimal amount, String? note}) {
  final parts = payee.query.split('&').where((p) => p.isNotEmpty).toList();
  String keyOf(String part) {
    final eq = part.indexOf('=');
    return (eq < 0 ? part : part.substring(0, eq)).trim().toLowerCase();
  }

  void put(String key, String value) {
    final field = '$key=$value';
    final i = parts.indexWhere((p) => keyOf(p) == key);
    if (i < 0) {
      parts.add(field);
    } else {
      parts[i] = field; // a blank "am=" or "am=0": the typed amount, in place
    }
  }

  if (!payee.fixedAmount) put('am', amount.toStringAsFixed(2));
  if (!payee.signed) {
    if ((payee.params['cu'] ?? '').isEmpty) put('cu', 'INR');
    final n = note?.trim() ?? '';
    if (n.isNotEmpty && payee.note == null) put('tn', Uri.encodeComponent(n));
  }
  // A name printed with plain spaces ("pn=Sri Sai Stores") is the one change:
  // %20 reads the same, and keeps the link valid for the UPI app.
  return Uri.parse('upi://pay?${parts.join('&').replaceAll(' ', '%20')}');
}

enum UpiStatus {
  /// The UPI app says it went through.
  success,

  /// Sent, still being processed by the bank — money usually follows.
  submitted,

  /// The UPI app says it failed (or the person backed out).
  failure,

  /// The UPI app said nothing either way.
  unknown,
}

class UpiOutcome {
  const UpiOutcome(
    this.status, {
    this.txnId,
    this.approvalRef,
    this.responseCode,
  });
  final UpiStatus status;

  /// The UPI app's response code ("U16", "ZM"…), when it sends one: on a
  /// failure, it says why the bank or the app declined.
  final String? responseCode;

  /// The UPI transaction id, when the app sends one.
  final String? txnId;

  /// The bank's approval / UTR reference, when the app sends one.
  final String? approvalRef;

  /// The best reference to note against the expense.
  String? get reference => approvalRef ?? txnId;
}

/// What the UPI app reported: the spec's
/// "txnId=…&responseCode=…&Status=SUCCESS&ApprovalRefNo=…" string, whose
/// keys' case varies by app. No answer is [UpiStatus.unknown], never failure:
/// several apps return nothing even after a payment went through.
UpiOutcome parseUpiResponse(String? response) {
  if (response == null || response.trim().isEmpty) {
    return const UpiOutcome(UpiStatus.unknown);
  }
  final f = <String, String>{};
  for (final part in response.split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    f[part.substring(0, eq).trim().toLowerCase()] = _decode(
      part.substring(eq + 1),
    ).trim();
  }
  String? orNull(String? s) =>
      (s == null || s.isEmpty || s.toLowerCase() == 'null') ? null : s;
  final status = switch ((f['status'] ?? '').toUpperCase()) {
    'SUCCESS' => UpiStatus.success,
    'SUBMITTED' || 'PENDING' => UpiStatus.submitted,
    'FAILURE' || 'FAILED' => UpiStatus.failure,
    _ => UpiStatus.unknown,
  };
  return UpiOutcome(
    status,
    txnId: orNull(f['txnid']),
    approvalRef: orNull(f['approvalrefno']),
    responseCode: orNull(f['responsecode']),
  );
}
