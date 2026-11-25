import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/payment_capture/domain/detected_payment.dart';
import 'package:finroot_mobile/features/payment_capture/domain/shared_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Shared from Messages → Share → "Add to FinRoot". Amounts and references
// are invented; the wording follows Indian bank alerts.
final now = DateTime(2026, 11, 25, 18, 30);

void main() {
  test('a shared debit SMS becomes a payment, dated as printed', () {
    final p = paymentFromSharedText(
      'Rs.1,250.00 debited from A/c XX1234 on 12-11-26 14:05 to SWIGGY. '
      'UPI Ref 512345678901',
      now: now,
    )!;
    expect(p.amount.amount, Decimal.parse('1250'));
    expect(p.direction, PaymentDirection.paid);
    expect(p.occurredAt, DateTime(2026, 11, 12, 14, 5));
    expect(p.reference, '512345678901');
    expect(p.paymentMode, 'UPI');
    expect(p.sources, ['Shared message']);
    expect(p.noticeIds, [kSharedNoticeId]);
  });

  test('a credit with an old date and no time lands at noon that day', () {
    final p = paymentFromSharedText(
      'INR 85,000.00 credited to A/c XX1234 on 01-Oct-26 by NEFT from ACME',
      now: now,
    )!;
    expect(p.direction, PaymentDirection.received);
    expect(p.occurredAt, DateTime(2026, 10, 1, 12));
  });

  test("today's date without a time is now; no date is now", () {
    expect(sharedMessageTime('debited on 25-11-26 to X', now: now), now);
    expect(sharedMessageTime('Rs 500 debited to X', now: now), now);
  });

  test('not a payment: OTPs, reminders, no amount', () {
    expect(
      paymentFromSharedText('Your OTP is 123456 for Rs 500 txn', now: now),
      isNull,
    );
    expect(
      paymentFromSharedText('EMI of Rs 2,500 is due on 05-12-26', now: now),
      isNull,
    );
    expect(paymentFromSharedText('See you at 5', now: now), isNull);
  });
}
