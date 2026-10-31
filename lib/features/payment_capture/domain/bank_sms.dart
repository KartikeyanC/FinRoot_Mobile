import 'package:decimal/decimal.dart';

import 'detected_payment.dart';
import 'ingest_hash.dart';

/// Stage 7, source 1 — local extraction for Indian bank SMS alerts.
///
/// Everything here runs on the phone at no cost: the text of an SMS alert goes
/// in, structured fields come out, and nothing is sent anywhere until the
/// person adds the payment. It reads alerts the way the rest of payment
/// detection does (`parsePaymentNotice`: amount, direction, payee, reference,
/// mode, with OTPs / reminders / failed payments rejected) and adds the fields
/// the ingestion pipeline needs: your account's last four, the time the bank
/// printed, the bank — and the de-dup hash.
///
/// How the alert reaches the phone: Android shows each incoming SMS as a
/// notification from the SMS app, and `PaymentListenerService.kt` (a
/// NotificationListenerService the person switches on) passes bank alerts
/// through. That needs no READ_SMS / RECEIVE_SMS permission, which Google Play
/// restricts to default SMS apps — a BroadcastReceiver on SMS_RECEIVED would
/// need exactly that.
class BankSmsExtract {
  const BankSmsExtract({
    required this.amount,
    required this.type,
    required this.occurredAt,
    this.merchant,
    this.accountLast4,
    this.reference,
    this.paymentMode,
    this.bank,
  });

  final Decimal amount;
  final IngestType type;

  /// The bank's printed date and time when the alert has both, else when the
  /// SMS arrived.
  final DateTime occurredAt;

  /// Who was paid / who paid — a merchant, a name or a UPI id.
  final String? merchant;
  final String? accountLast4;

  /// UPI RRN / UTR / bank reference — the cross-source de-dup key.
  final String? reference;
  final String? paymentMode;
  final String? bank;

  /// The key the database de-duplicates on (`raw_payload_hash`).
  String hashFor(String userId) => rawPayloadHash(
    userId: userId,
    amount: amount,
    type: type,
    occurredAt: occurredAt,
    accountLast4: accountLast4,
  );
}

/// Extracts one bank SMS. [sender] is the DLT sender id ("AD-HDFCBK"); the
/// result is null for anything that is not a completed debit or credit.
BankSmsExtract? extractBankSms(
  String body, {
  required DateTime receivedAt,
  String sender = '',
}) {
  final p = parsePaymentNotice(
    PaymentNotice(
      id: 'sms',
      packageName: 'com.google.android.apps.messaging',
      title: sender,
      text: body,
      postedAt: receivedAt,
    ),
  );
  return p == null ? null : bankSmsExtractOf(p);
}

/// The ingestion view of a payment already detected from notices.
BankSmsExtract bankSmsExtractOf(DetectedPayment p) => BankSmsExtract(
  amount: p.amount.amount,
  type: p.isPaid ? IngestType.expense : IngestType.income,
  occurredAt: p.occurredAt,
  merchant: p.counterparty,
  accountLast4: p.accountLast4,
  reference: p.reference,
  paymentMode: p.paymentMode,
  bank: p.bank,
);

/// `sms` when a bank SMS was among the payment's sources, else `notification`
/// (a UPI or bank app's own notification).
String ingestSourceOf(DetectedPayment p) =>
    p.sources.contains('Bank SMS') ? 'sms' : 'notification';

/// The named arguments of the `ingest_transaction` RPC (migration
/// `20261031120000_stage7_auto_ingest.sql`) for a detected payment, with
/// [category] and an optional [note] chosen by the person.
Map<String, Object?> ingestRpcArgs(
  DetectedPayment p, {
  required String tenantId,
  required String userId,
  String category = 'Other',
  String? note,
}) {
  final x = bankSmsExtractOf(p);
  final description = [
    if (x.merchant != null) x.merchant!,
    if (note != null && note.trim().isNotEmpty) note.trim(),
  ].join(' · ');
  return {
    'p_tenant_id': tenantId,
    'p_user_id': userId,
    'p_source': ingestSourceOf(p),
    'p_raw_payload_hash': x.hashFor(userId),
    'p_type': x.type.wire,
    'p_amount': x.amount.toStringAsFixed(2),
    'p_occurred_at': x.occurredAt.toUtc().toIso8601String(),
    'p_currency': 'INR',
    'p_category': category,
    'p_description': description.isEmpty ? null : description,
    'p_account_last4': x.accountLast4,
    'p_external_ref': x.reference,
    'p_payment_mode': x.paymentMode,
  };
}
