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

  String get displayName => name ?? vpa;
  bool get fixedAmount => amount != null;
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

  final params = <String, String>{};
  for (final part in text.substring(q + 1).split('&')) {
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
  );
}

String _decode(String s) {
  try {
    return Uri.decodeQueryComponent(s);
  } on Object {
    return s; // a stray "%" in a shop's name: keep it as written
  }
}

/// The link handed to the UPI app: the QR's own fields, with the amount the
/// person typed (unless the QR fixed one), INR, and their note when the QR
/// had none.
Uri upiPayUri(UpiPayee payee, {required Decimal amount, String? note}) {
  final fields = Map<String, String>.of(payee.params);
  if (!payee.fixedAmount) fields['am'] = amount.toStringAsFixed(2);
  fields['cu'] = 'INR';
  final n = note?.trim() ?? '';
  if (n.isNotEmpty && (fields['tn'] ?? '').isEmpty) fields['tn'] = n;
  final query = fields.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return Uri.parse('upi://pay?$query');
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
  const UpiOutcome(this.status, {this.txnId, this.approvalRef});
  final UpiStatus status;

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
  );
}
