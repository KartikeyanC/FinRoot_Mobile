import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/payment_capture/domain/detected_payment.dart';
import 'package:finroot_mobile/features/transactions/domain/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

const gpay = 'com.google.android.apps.nbu.paisa.user';
const phonepe = 'com.phonepe.app';
const paytm = 'net.one97.paytm';
const sms = 'com.google.android.apps.messaging';

final t0 = DateTime(2026, 10, 28, 14, 30);
var _n = 0;

PaymentNotice notice(
  String pkg,
  String title,
  String text, {
  Duration after = Duration.zero,
}) => PaymentNotice(
  id: 'n${_n++}',
  packageName: pkg,
  title: title,
  text: text,
  postedAt: t0.add(after),
);

DetectedPayment? parse(String pkg, String title, String text) =>
    parsePaymentNotice(notice(pkg, title, text));

Money rs(String v) => Money(Decimal.parse(v));

void main() {
  group('UPI app notifications', () {
    test('Google Pay "paid to"', () {
      final p = parse(gpay, '₹500 paid to Ravi Kumar', 'UPI ID: ravi@okaxis')!;
      expect(p.amount, rs('500'));
      expect(p.direction, PaymentDirection.paid);
      expect(p.counterparty, 'Ravi Kumar');
      expect(p.paymentMode, 'UPI');
      expect(p.sources, ['Google Pay']);
      expect(p.headline, 'Paid to Ravi Kumar');
    });

    test('PhonePe with spaces and a merchant in capitals', () {
      final p = parse(
        phonepe,
        'Payment Successful',
        'Paid ₹ 1,249.50 to SWIGGY',
      )!;
      expect(p.amount, rs('1249.50'));
      expect(p.counterparty, 'Swiggy');
    });

    test('person in the title, amount in the text', () {
      final p = parse(gpay, 'Anitha', 'You received ₹2,000')!;
      expect(p.direction, PaymentDirection.received);
      expect(p.counterparty, 'Anitha');
      expect(p.headline, 'Received from Anitha');
    });

    test('Paytm received from', () {
      final p = parse(
        paytm,
        'Money Received',
        'Received Rs.350 from Suresh K',
      )!;
      expect(p.direction, PaymentDirection.received);
      expect(p.amount, rs('350'));
      expect(p.counterparty, 'Suresh K');
    });
  });

  group('bank SMS', () {
    test('SBI debit with no currency sign, payee after "trf to"', () {
      final p = parse(
        sms,
        'JM-SBIUPI',
        'Dear UPI user A/C X1234 debited by 500.0 on date 28Oct26 trf to '
            'RAVI KUMAR Refno 430112345678. If not u? call 1800111109. -SBI',
      )!;
      expect(p.amount, rs('500'));
      expect(p.direction, PaymentDirection.paid);
      expect(p.counterparty, 'Ravi Kumar');
      expect(p.reference, '430112345678');
      expect(p.sources, ['Bank SMS']);
    });

    test('HDFC "Sent … To" with a VPA', () {
      final p = parse(
        sms,
        'AD-HDFCBK',
        'Sent Rs.120.00 From HDFC Bank A/C x5678 To swiggy@ybl On 28/10/26 '
            'Ref 430198765432 Not You? Call 18002586161',
      )!;
      expect(p.amount, rs('120'));
      expect(p.counterparty, 'swiggy@ybl');
      expect(p.paymentMode, 'UPI');
    });

    test('card spend "at" a merchant, balance ignored', () {
      final p = parse(
        sms,
        'VM-ICICIB',
        'Avl Lmt Rs 45,000. INR 2,499.00 spent on ICICI Bank Card XX9012 '
            'at AMAZON on 28-Oct-26.',
      )!;
      expect(p.amount, rs('2499'));
      expect(p.counterparty, 'Amazon');
      expect(p.paymentMode, 'Card');
    });

    test('credit to the account, payer after "by"', () {
      final p = parse(
        sms,
        'AX-AXISBK',
        'INR 5,000.00 credited to A/c no. XX3456 on 28-10-26 by '
            'VPA anitha@oksbi (UPI Ref no 430155554444)',
      )!;
      expect(p.direction, PaymentDirection.received);
      expect(p.counterparty, 'anitha@oksbi');
      expect(p.reference, '430155554444');
    });

    test('an SMS sender id is never taken as the payee', () {
      final p = parse(sms, 'AD-HDFCBK', 'Rs.99 debited from A/c XX5678')!;
      expect(p.counterparty, isNull);
      expect(p.headline, 'Payment made');
    });
  });

  group('not payments', () {
    for (final (why, title, text) in [
      ('OTP', 'AD-HDFCBK', 'OTP 123456 for txn of Rs.500 at AMAZON'),
      ('collect request', 'PhonePe', 'Ravi has requested ₹500'),
      ('due reminder', 'CRED', 'Your card bill of ₹4,500 is due on 5 Nov'),
      ('failed', 'Google Pay', 'Payment of ₹200 to Ravi failed'),
      ('autopay notice', 'AD-SBIINB', 'Rs.199 will be debited on 1 Nov'),
      ('offer', 'Paytm', 'Get up to ₹100 cashback on your next payment'),
      ('no amount', 'Google Pay', 'Payment received'),
    ]) {
      test(why, () => expect(parse(sms, title, text), isNull));
    }
  });

  group('detectPayments', () {
    test('folds the UPI app and the bank SMS for one payment together', () {
      final out = detectPayments([
        notice(gpay, '₹500 paid to Ravi Kumar', ''),
        notice(
          sms,
          'JM-SBIUPI',
          'A/C X1234 debited by 500.0 on 28Oct26 trf to RAVI KUMAR '
              'Refno 430112345678',
          after: const Duration(seconds: 40),
        ),
      ]);
      expect(out, hasLength(1));
      expect(out.single.noticeIds, hasLength(2));
      expect(out.single.sources, ['Google Pay', 'Bank SMS']);
      expect(out.single.reference, '430112345678');
    });

    test('two real payments of the same amount stay apart', () {
      final out = detectPayments([
        notice(gpay, '₹50 paid to Tea Stall', ''),
        notice(
          gpay,
          '₹50 paid to Tea Stall',
          '',
          after: const Duration(hours: 3),
        ),
      ]);
      expect(out, hasLength(2));
      expect(out.first.occurredAt.isAfter(out.last.occurredAt), isTrue);
    });
  });

  test('looksAlreadyRecorded matches amount, type and day', () {
    final p = parsePaymentNotice(notice(gpay, '₹500 paid to Ravi', ''))!;
    TransactionEntity txn(TxnType type, String amt, Duration off) =>
        TransactionEntity(
          id: 'x',
          type: type,
          amount: rs(amt),
          category: 'Food & Dining',
          occurredAt: t0.add(off),
        );
    expect(
      looksAlreadyRecorded(p, [
        txn(TxnType.expense, '500.00', const Duration(hours: 2)),
      ]),
      isTrue,
    );
    expect(
      looksAlreadyRecorded(p, [txn(TxnType.income, '500', Duration.zero)]),
      isFalse,
    );
    expect(
      looksAlreadyRecorded(p, [
        txn(TxnType.expense, '500', const Duration(days: 3)),
      ]),
      isFalse,
    );
  });
}
