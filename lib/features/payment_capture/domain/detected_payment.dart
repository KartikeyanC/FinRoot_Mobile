import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';
import '../../../domain/constants.dart';
import '../../transactions/domain/transaction.dart';
import 'sms_fields.dart';

/// One notification the Android listener kept because it looked like a
/// payment — raw text, not yet understood.
class PaymentNotice {
  const PaymentNotice({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  factory PaymentNotice.fromJson(Map<String, dynamic> j) => PaymentNotice(
    id: j['id'] as String,
    packageName: j['package'] as String? ?? '',
    title: j['title'] as String? ?? '',
    text: j['text'] as String? ?? '',
    postedAt: DateTime.fromMillisecondsSinceEpoch(
      (j['postedAt'] as num).toInt(),
    ),
  );

  final String id;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;
}

enum PaymentDirection { paid, received }

/// A payment understood from one or more notices — the same payment often
/// shows up twice (the UPI app and the bank's SMS), so [noticeIds] can hold
/// several.
class DetectedPayment {
  const DetectedPayment({
    required this.noticeIds,
    required this.amount,
    required this.direction,
    required this.occurredAt,
    required this.sources,
    this.counterparty,
    this.reference,
    this.paymentMode,
    this.accountLast4,
    this.bank,
  });

  final List<String> noticeIds;
  final Money amount;
  final PaymentDirection direction;
  final DateTime occurredAt;

  /// App names the payment was seen in, e.g. ["Google Pay", "Bank SMS"].
  final List<String> sources;

  /// Who was paid / who paid — a name, merchant or UPI id.
  final String? counterparty;

  /// UPI ref / UTR / transaction id when the notice carries one.
  final String? reference;

  /// One of [kPaymentModes] when it can be told ("UPI", "Card").
  final String? paymentMode;

  /// Last four digits of your account or card, when a bank alert names it.
  /// Part of the ingest de-dup key (`ingest_hash.dart`).
  final String? accountLast4;

  /// The bank, from an SMS sender id ("AD-HDFCBK" → "HDFC Bank").
  final String? bank;

  String get id => noticeIds.first;

  bool get isPaid => direction == PaymentDirection.paid;

  /// "Paid to Ravi Kumar" / "Received from Swiggy" / "Payment".
  String get headline => switch ((direction, counterparty)) {
    (PaymentDirection.paid, final String who) => 'Paid to $who',
    (PaymentDirection.received, final String who) => 'Received from $who',
    (PaymentDirection.paid, null) => 'Payment made',
    (PaymentDirection.received, null) => 'Money received',
  };

  DetectedPayment _mergedWith(DetectedPayment o) => DetectedPayment(
    noticeIds: [...noticeIds, ...o.noticeIds],
    amount: amount,
    direction: direction,
    occurredAt: occurredAt.isBefore(o.occurredAt) ? occurredAt : o.occurredAt,
    sources: {...sources, ...o.sources}.toList(),
    counterparty: counterparty ?? o.counterparty,
    reference: reference ?? o.reference,
    paymentMode: paymentMode ?? o.paymentMode,
    accountLast4: accountLast4 ?? o.accountLast4,
    bank: bank ?? o.bank,
  );
}

// ---------------------------------------------------------------------------
// Parsing

const _appNames = <String, String>{
  'com.google.android.apps.nbu.paisa.user': 'Google Pay',
  'com.phonepe.app': 'PhonePe',
  'net.one97.paytm': 'Paytm',
  'in.org.npci.upiapp': 'BHIM',
  'in.amazon.mShop.android.shopping': 'Amazon Pay',
  'com.dreamplug.androidapp': 'CRED',
  'com.mobikwik_new': 'MobiKwik',
  'com.freecharge.android': 'Freecharge',
  'money.super.payments': 'super.money',
  'com.fampay.in': 'FamPay',
  'com.sbi.lotusintouch': 'SBI YONO',
  'com.sbi.upi': 'BHIM SBI Pay',
  'com.snapwork.hdfc': 'HDFC Bank',
  'com.hdfcbank.payzapp': 'PayZapp',
  'com.csam.icici.bank.imobile': 'ICICI iMobile',
  'com.axis.mobile': 'Axis Mobile',
  'com.msf.kbank.mobile': 'Kotak',
  'com.canarabank.mobility': 'Canara ai1',
  'com.bankofbaroda.mconnect': 'Bank of Baroda',
  'com.infrasoft.uboi': 'Union Bank',
  'com.fss.indus': 'IndusInd',
  'com.idfcfirstbank.optimus': 'IDFC FIRST',
  'com.YesBank': 'Yes Bank',
  'com.pnb.pnbone': 'PNB ONE',
};

const _smsApps = {
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.mms',
  'com.android.messaging',
  'com.oneplus.mms',
  'com.miui.smsextra',
  'com.truecaller',
  'com.microsoft.android.smsorganizer',
};

const _upiApps = {
  'com.google.android.apps.nbu.paisa.user',
  'com.phonepe.app',
  'net.one97.paytm',
  'in.org.npci.upiapp',
  'com.sbi.upi',
  'money.super.payments',
};

/// True for a notification posted by an SMS app — a bank alert, not an app.
bool isSmsPackage(String packageName) => _smsApps.contains(packageName);

String sourceLabel(String packageName) => _smsApps.contains(packageName)
    ? 'Bank SMS'
    : _appNames[packageName] ?? packageName;

RegExp _re(String p) => RegExp(p, caseSensitive: false);

final _reject = _re(
  r'\b(otp|one[ -]?time password|verification code|passcode|'
  r'request(?:ed|s)?|reminder|due (?:on|date|by)|is due|minimum (?:amount )?due|'
  r'will be (?:debited|credited|deducted)|scheduled|failed|declined|'
  r'unsuccessful|offer|win|get up to|bill (?:is )?generated)\b',
);
final _currencyAmount = _re(
  r'(?:₹|\brs\.?|\binr)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
);
final _bareAmount = _re(
  r'\b(?:debited|credited)\s+(?:by|for|with)\s+([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
);
final _balanceBefore = _re(r'\b(bal(?:ance)?|lmt|limit)[^0-9]{0,12}$');
final _debit = _re(
  r'\b(paid|sent|debited|spent|withdrawn|purchase|transferred|payment of|paying)\b',
);
final _credit = _re(
  r'\b(received|credited|refund(?:ed)?|deposited|cashback|added to your)\b',
);

const _name = r"([A-Za-z0-9@][A-Za-z0-9 .&'@_\-]{1,40}?)";
const _nameEnd =
    r'(?=\s+(?:on|via|using|from|ref|refno|upi|utr|is|has|for|at|avl|bal|txn|'
    r'thru|through|a/c|ac|in|with|and)\b|\s*[.,;:!()\n]|\s*$)';
final _paidTo = [
  _re(
    r'\b(?:paid|sent|transferred|payment)\s+(?:of\s+)?'
    r'(?:(?:₹|rs\.?|inr)\s*[0-9,]+(?:\.[0-9]+)?\s+)?(?:successfully\s+)?'
    'to\\s+(?:vpa\\s+)?$_name$_nameEnd',
  ),
  _re('\\b(?:trf|transfer)\\s+to\\s+(?:vpa\\s+)?$_name$_nameEnd'),
  _re('\\b(?:spent|purchase|txn|transaction)\\b.*?\\bat\\s+$_name$_nameEnd'),
  _re('\\bto\\s+(?:vpa\\s+)?$_name$_nameEnd'),
];
final _receivedFrom = [
  _re('\\bfrom\\s+(?:vpa\\s+)?$_name$_nameEnd'),
  _re('\\bby\\s+(?:vpa\\s+)?$_name$_nameEnd'),
];
final _notAName = _re(
  r'^(?:your|you|self|me|a/?c|acct|account|card|bank|the|an?|upi|beneficiary)\b'
  r'|x{2,}\d+|^\d+$',
);
final _genericTitle = _re(
  r'payment|paid|received|debited|credited|transaction|txn|alert|bank|'
  r'success|money|transfer|upi|wallet|\d',
);
final _reference = _re(
  r'(?:upi\s*ref(?:\s*no)?|ref(?:erence)?\s*(?:no|number|id)?|refno|utr|'
  r'txn\s*id|transaction\s*id)[\s:.#-]*([A-Za-z0-9]{6,})',
);
final _upiHint = _re(r'\bupi\b|\bvpa\b|@(?:ok|ybl|ibl|axl|paytm|apl|upi)');
final _cardHint = _re(r'\b(?:credit|debit)?\s*card\b');

/// Reads one notice. Null when it isn't a completed payment (an OTP, a
/// payment request, a due-date reminder, a failed payment, no amount…).
DetectedPayment? parsePaymentNotice(PaymentNotice n) {
  final isSms = _smsApps.contains(n.packageName);
  final text = '${n.title} ${n.text}'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_reject.hasMatch(text)) return null;

  final amount = _amountIn(text);
  if (amount == null) return null;

  final d = _debit.firstMatch(text)?.start;
  final c = _credit.firstMatch(text)?.start;
  if (d == null && c == null) return null;
  final direction = (c == null || (d != null && d < c))
      ? PaymentDirection.paid
      : PaymentDirection.received;

  var who = _firstName(
    direction == PaymentDirection.paid ? _paidTo : _receivedFrom,
    text,
  );
  // App notifications often put the person in the title ("Ravi Kumar" /
  // "You paid ₹200"). An SMS title is the bank's sender id — never a payee.
  if (who == null && !isSms) {
    final t = n.title.trim();
    if (t.length >= 2 && t.length <= 40 && !_genericTitle.hasMatch(t)) {
      who = _tidyName(t);
    }
  }

  final ref = _reference
      .allMatches(text)
      .map((m) => m.group(1)!)
      .where((r) => RegExp(r'\d{6,}').hasMatch(r))
      .firstOrNull;

  final String? mode;
  if (_cardHint.hasMatch(text)) {
    mode = 'Card';
  } else if (_upiApps.contains(n.packageName) || _upiHint.hasMatch(text)) {
    mode = 'UPI';
  } else {
    mode = null;
  }
  assert(mode == null || kPaymentModes.contains(mode));

  // A bank SMS prints when the bank booked it; prefer that minute to when the
  // phone happened to receive it (both feed the de-dup key).
  final occurredAt = isSms
      ? alertTimeIn(text, receivedAt: n.postedAt) ?? n.postedAt
      : n.postedAt;

  return DetectedPayment(
    noticeIds: [n.id],
    amount: amount,
    direction: direction,
    occurredAt: occurredAt,
    sources: [sourceLabel(n.packageName)],
    counterparty: who,
    reference: ref,
    paymentMode: mode,
    accountLast4: accountLast4In(text),
    bank: isSms ? bankFromSender(n.title) : null,
  );
}

Money? _amountIn(String text) {
  for (final re in [_currencyAmount, _bareAmount]) {
    for (final m in re.allMatches(text)) {
      // Skip "Avl Bal Rs 10,000" / "limit Rs …" — not the payment.
      if (_balanceBefore.hasMatch(text.substring(0, m.start))) continue;
      final value = Decimal.tryParse(m.group(1)!.replaceAll(',', ''));
      if (value == null || value <= Decimal.zero) continue;
      return Money(value);
    }
  }
  return null;
}

String? _firstName(List<RegExp> patterns, String text) {
  for (final re in patterns) {
    for (final m in re.allMatches(text)) {
      final name = _tidyName(m.group(1)!);
      if (name != null) return name;
    }
  }
  return null;
}

String? _tidyName(String raw) {
  final s = raw.trim().replaceAll(RegExp(r'[.\-_ ]+$'), '');
  if (s.length < 2 || _notAName.hasMatch(s)) return null;
  // "RAVI KUMAR" → "Ravi Kumar"; leave UPI ids and mixed case alone.
  if (!s.contains('@') && s == s.toUpperCase() && s.contains(RegExp('[A-Z]'))) {
    return s
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
  return s;
}

/// Parses every notice and folds duplicates of one payment together: the
/// same amount and direction seen in another app within 10 minutes (UPI app
/// + bank SMS), the same reference number, or a repeat from the same app
/// within 2 minutes. Newest first.
List<DetectedPayment> detectPayments(Iterable<PaymentNotice> notices) {
  final parsed = notices.map(parsePaymentNotice).nonNulls.toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final out = <DetectedPayment>[];
  for (final p in parsed) {
    final i = out.indexWhere((q) => _samePayment(q, p));
    if (i == -1) {
      out.add(p);
    } else {
      out[i] = out[i]._mergedWith(p);
    }
  }
  return out.reversed.toList();
}

bool _samePayment(DetectedPayment a, DetectedPayment b) {
  if (a.amount != b.amount || a.direction != b.direction) return false;
  if (a.reference != null && a.reference == b.reference) return true;
  final gap = a.occurredAt.difference(b.occurredAt).abs();
  final sameSource = a.sources.any(b.sources.contains);
  return gap <=
      (sameSource ? const Duration(minutes: 2) : const Duration(minutes: 10));
}

/// True when the ledger already has a matching row — same amount and type,
/// within a day — so the review list can say "Looks already added".
bool looksAlreadyRecorded(
  DetectedPayment p,
  Iterable<TransactionEntity> ledger,
) {
  final type = p.isPaid ? TxnType.expense : TxnType.income;
  return ledger.any(
    (t) =>
        t.type == type &&
        t.amount == p.amount &&
        t.occurredAt.difference(p.occurredAt).abs() <= const Duration(days: 1),
  );
}
