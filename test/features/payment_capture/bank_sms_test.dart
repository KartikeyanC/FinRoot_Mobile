import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/payment_capture/domain/bank_sms.dart';
import 'package:finroot_mobile/features/payment_capture/domain/detected_payment.dart';
import 'package:finroot_mobile/features/payment_capture/domain/ingest_hash.dart';
import 'package:finroot_mobile/features/payment_capture/domain/sms_fields.dart';
import 'package:flutter_test/flutter_test.dart';

// Alert wording modelled on the formats Indian banks send (amounts, numbers
// and references invented). Times are device-local, as on the phone.
final received = DateTime(2026, 10, 31, 14, 6);
const user = '22222222-2222-2222-2222-222222222222';
const tenant = '11111111-1111-1111-1111-111111111111';

BankSmsExtract? x(String body, {String sender = 'AD-HDFCBK', DateTime? at}) =>
    extractBankSms(body, receivedAt: at ?? received, sender: sender);

void main() {
  group('extracts Indian bank alerts', () {
    test('HDFC UPI debit, date only → arrival time', () {
      final e = x(
        'Sent Rs.250.00 From HDFC Bank A/C *5678 To SWIGGY On 31/10/26 '
        'Ref 430412345678 Not You? Call 18002586161/SMS BLOCK UPI to 7308080808',
      )!;
      expect(e.amount, Decimal.parse('250'));
      expect(e.type, IngestType.expense);
      expect(e.accountLast4, '5678');
      expect(e.merchant, 'Swiggy');
      expect(e.reference, '430412345678');
      expect(e.paymentMode, 'UPI');
      expect(e.bank, 'HDFC Bank');
      expect(e.occurredAt, received);
    });

    test('SBI "debited by" with a bare amount and trf to', () {
      final e = x(
        'Dear UPI user A/C X1234 debited by 120.0 on date 31Oct26 trf to ZOMATO '
        'Refno 430498765432. If not u? call 1800111109. -SBI',
        sender: 'VM-SBIUPI',
      )!;
      expect(e.amount, Decimal.parse('120'));
      expect(e.type, IngestType.expense);
      expect(e.accountLast4, '1234');
      expect(e.merchant, 'Zomato');
      expect(e.reference, '430498765432');
      expect(e.bank, 'SBI');
    });

    test('ICICI card spend skips the available limit', () {
      final e = x(
        'INR 1,499.00 spent using ICICI Bank Card XX4321 on 31-Oct-26 on AMAZON. '
        'Avl Limit: INR 48,501.00. If not you, call 1800 2662.',
        sender: 'JD-ICICIT',
      )!;
      expect(e.amount, Decimal.parse('1499'));
      expect(e.accountLast4, '4321');
      expect(e.paymentMode, 'Card');
      expect(e.bank, 'ICICI Bank');
    });

    test('Axis credit with a printed time and an unbroken balance', () {
      final e = x(
        'INR 25,000.00 credited to A/c no. XX9012 on 31-10-26 at 10:15:42 IST. '
        'Info- NEFT/ACME CORP. Avl Bal INR 1,02,345.00 - Axis Bank',
        sender: 'AX-AXISBK',
        at: DateTime(2026, 10, 31, 10, 16),
      )!;
      expect(e.type, IngestType.income);
      expect(e.amount, Decimal.parse('25000'));
      expect(e.accountLast4, '9012');
      expect(e.occurredAt, DateTime(2026, 10, 31, 10, 15, 42));
      expect(e.bank, 'Axis Bank');
    });

    test('Kotak debit to a VPA with a 24-hour time', () {
      final e = x(
        'Rs.500.00 debited from a/c XXXXXX3456 on 31/10/2026 14:05:12 to VPA '
        'ravi@okaxis (UPI Ref No 430411112222). - Kotak Bank',
        sender: 'VK-KOTAKB',
      )!;
      expect(e.accountLast4, '3456');
      expect(e.occurredAt, DateTime(2026, 10, 31, 14, 5, 12));
      expect(e.merchant, 'ravi@okaxis');
      expect(e.reference, '430411112222');
      expect(e.bank, 'Kotak');
    });

    test('12-hour clock', () {
      final e = x(
        'Rs 99 debited from A/c XX5678 on 31-Oct-2026 at 2:05 PM for UPI txn '
        'to PAYTM. Ref 430400001111',
      )!;
      expect(e.occurredAt, DateTime(2026, 10, 31, 14, 5));
    });
  });

  group('rejects what is not a completed payment', () {
    for (final (why, body) in [
      (
        'an OTP',
        '123456 is OTP for txn of Rs.2,000 at AMAZON on card XX4321. Do not share.',
      ),
      (
        'a due reminder',
        'Your Credit Card XX4321 bill of Rs.12,345 is due on 05-11-26.',
      ),
      (
        'a failed payment',
        'Txn of Rs.300 from A/c XX5678 failed. Amount will not be debited.',
      ),
      (
        'a collect request',
        'ravi@okaxis has requested Rs.150 from you on UPI.',
      ),
      ('no amount', 'Your A/c XX5678 statement for October is ready.'),
    ]) {
      test(why, () => expect(x(body), isNull));
    }
  });

  group('accountLast4In', () {
    for (final (text, want) in [
      ('A/c XX5678 debited', '5678'),
      ('a/c no. XXXXXX5678', '5678'),
      ('Acct *5678', '5678'),
      ('card ending 4321', '4321'),
      ('Card ending with XX4321', '4321'),
      ('Credit Card xx4321', '4321'),
      ('A/c no 123456789012 credited', '9012'),
      ('A/c XX567 debited', null),
      ('paid to ravi@okaxis', null),
    ]) {
      test('$text → $want', () => expect(accountLast4In(text), want));
    }

    test('takes the account named first (yours, not the payee)', () {
      expect(
        accountLast4In('A/c XX5678 debited, credited to A/c XX9999'),
        '5678',
      );
    });
  });

  group('alertTimeIn', () {
    test(
      'a date without a time gives null (the caller keeps arrival time)',
      () {
        expect(
          alertTimeIn('on 31-10-26 to SWIGGY', receivedAt: received),
          isNull,
        );
      },
    );

    test('distrusts a time from the future', () {
      expect(alertTimeIn('on 31-12-26 10:00', receivedAt: received), isNull);
    });

    test('distrusts a time days before the alert arrived', () {
      expect(alertTimeIn('on 01-10-26 10:00', receivedAt: received), isNull);
    });

    test('accepts a delayed SMS within a few hours', () {
      expect(
        alertTimeIn('on 31-10-26 09:30', receivedAt: received),
        DateTime(2026, 10, 31, 9, 30),
      );
    });

    test('rejects impossible dates and clocks', () {
      expect(alertTimeIn('on 31-02-26 10:00', receivedAt: received), isNull);
      expect(alertTimeIn('on 31-10-26 25:00', receivedAt: received), isNull);
      expect(alertTimeIn('on 31-10-26 13:00 PM', receivedAt: received), isNull);
    });

    test('ISO dates', () {
      expect(
        alertTimeIn('2026-10-31 13:59:59', receivedAt: received),
        DateTime(2026, 10, 31, 13, 59, 59),
      );
    });
  });

  test('bankFromSender', () {
    expect(bankFromSender('AD-HDFCBK'), 'HDFC Bank');
    expect(bankFromSender('VM-SBIINB'), 'SBI');
    expect(bankFromSender('BZ-CNRBNK'), 'Canara Bank');
    expect(bankFromSender('AD-AMAZON'), isNull);
  });

  group('ingestion', () {
    test('the hash is the shared de-dup key over the extracted fields', () {
      final e = x(
        'Rs.1,234.50 debited from A/c XX5678 on 31-10-26 14:05:42 to SWIGGY. '
        'Ref 430411112222',
      )!;
      expect(
        e.hashFor(user),
        rawPayloadHash(
          userId: user,
          amount: Decimal.parse('1234.50'),
          type: IngestType.expense,
          occurredAt: DateTime(2026, 10, 31, 14, 5, 42),
          accountLast4: '5678',
        ),
      );
    });

    test('a UPI app notice and the bank SMS fold into one payment that keeps '
        "the SMS's account", () {
      final out = detectPayments([
        PaymentNotice(
          id: 'g',
          packageName: 'com.google.android.apps.nbu.paisa.user',
          title: '₹250 paid to Swiggy',
          text: 'UPI ID: swiggy@icici',
          postedAt: DateTime(2026, 10, 31, 14, 5, 30),
        ),
        PaymentNotice(
          id: 's',
          packageName: 'com.google.android.apps.messaging',
          title: 'AD-HDFCBK',
          text:
              'Sent Rs.250.00 From HDFC Bank A/C *5678 To SWIGGY On 31/10/26 '
              'Ref 430412345678',
          postedAt: DateTime(2026, 10, 31, 14, 5, 40),
        ),
      ]);
      expect(out, hasLength(1));
      expect(out.single.accountLast4, '5678');
      expect(out.single.bank, 'HDFC Bank');
      expect(ingestSourceOf(out.single), 'sms');
    });

    test('RPC arguments match ingest_transaction()', () {
      final p = parsePaymentNotice(
        PaymentNotice(
          id: 's',
          packageName: 'com.google.android.apps.messaging',
          title: 'VK-KOTAKB',
          text:
              'Rs.500.00 debited from a/c XXXXXX3456 on 31/10/2026 14:05:12 '
              'to VPA ravi@okaxis (UPI Ref No 430411112222).',
          postedAt: received,
        ),
      )!;
      final args = ingestRpcArgs(
        p,
        tenantId: tenant,
        userId: user,
        category: 'Food & Dining',
        note: 'lunch',
      );
      expect(args.keys.toSet(), {
        'p_tenant_id',
        'p_user_id',
        'p_source',
        'p_raw_payload_hash',
        'p_type',
        'p_amount',
        'p_occurred_at',
        'p_currency',
        'p_category',
        'p_description',
        'p_account_last4',
        'p_external_ref',
        'p_payment_mode',
      });
      expect(args['p_source'], 'sms');
      expect(args['p_type'], 'expense');
      expect(args['p_amount'], '500.00');
      expect(args['p_account_last4'], '3456');
      expect(args['p_external_ref'], '430411112222');
      expect(args['p_description'], 'ravi@okaxis · lunch');
      expect(args['p_raw_payload_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
      // Sent as UTC; the same instant as the bank's local 14:05:12.
      expect(args['p_occurred_at'], endsWith('Z'));
      expect(
        DateTime.parse(args['p_occurred_at']! as String)
            .isAtSameMomentAs(DateTime(2026, 10, 31, 14, 5, 12)),
        isTrue,
      );
    });
  });
}
