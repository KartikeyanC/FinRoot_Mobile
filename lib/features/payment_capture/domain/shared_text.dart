import 'detected_payment.dart';
import 'sms_fields.dart';

/// The id a shared message carries through the payment parser. It is never in
/// the detection queue, so nothing is removed from there when it is added.
const kSharedNoticeId = 'shared';

/// A payment in text shared to FinRoot (Messages → Share → "Add to FinRoot"),
/// read exactly as a bank SMS is, or null when the text is not a completed
/// payment (an OTP, a reminder, a failed payment, no amount…).
///
/// This is the way in that needs no notification access, so it works in the
/// side-loaded APK that Play Protect lets people install. A shared message
/// can be old, so its date is the one printed in it: with the printed time
/// when there is one, at the current time when it is today's, and at noon on
/// an earlier day without a time.
DetectedPayment? paymentFromSharedText(String text, {required DateTime now}) {
  final p = parsePaymentNotice(
    PaymentNotice(
      id: kSharedNoticeId,
      // Read as an SMS: the title is never taken for the payee.
      packageName: 'com.google.android.apps.messaging',
      title: '',
      text: text,
      postedAt: now,
    ),
  );
  if (p == null) return null;
  return DetectedPayment(
    noticeIds: p.noticeIds,
    amount: p.amount,
    direction: p.direction,
    occurredAt: sharedMessageTime(text, now: now),
    sources: const ['Shared message'],
    counterparty: p.counterparty,
    reference: p.reference,
    paymentMode: p.paymentMode,
    accountLast4: p.accountLast4,
    bank: p.bank,
  );
}

/// When a shared message's payment happened (see [paymentFromSharedText]).
DateTime sharedMessageTime(String text, {required DateTime now}) {
  final printed = messageDateIn(text, now: now);
  if (printed == null) return now;
  final noClock =
      printed.hour == 0 && printed.minute == 0 && printed.second == 0;
  if (!noClock) return printed.isAfter(now) ? now : printed;
  final today =
      printed.year == now.year &&
      printed.month == now.month &&
      printed.day == now.day;
  return today ? now : DateTime(printed.year, printed.month, printed.day, 12);
}
