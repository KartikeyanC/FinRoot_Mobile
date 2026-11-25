import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/features/upi_pay/domain/upi_qr.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('parseUpiQr', () {
    test('reads a shop QR with no amount', () {
      final p = parseUpiQr(
        'upi://pay?pa=srisai.stores@okaxis&pn=Sri%20Sai%20Stores&mc=5411'
        '&aid=uGICAgIDf8a',
      )!;
      expect(p.vpa, 'srisai.stores@okaxis');
      expect(p.name, 'Sri Sai Stores');
      expect(p.displayName, 'Sri Sai Stores');
      expect(p.fixedAmount, isFalse);
      expect(p.params['mc'], '5411');
    });

    test('a fixed amount and a note', () {
      final p = parseUpiQr(
        'upi://pay?pa=canteen@ybl&pn=Canteen&am=45.50&tn=Lunch&cu=INR',
      )!;
      expect(p.amount, d('45.50'));
      expect(p.fixedAmount, isTrue);
      expect(p.note, 'Lunch');
    });

    test('upper-case scheme and keys, a trailing slash, an unescaped name', () {
      final p = parseUpiQr('UPI://PAY/?PA=Ravi.K@oksbi&PN=Ravi Kumar&AM=0')!;
      expect(p.vpa, 'Ravi.K@oksbi');
      expect(p.name, 'Ravi Kumar');
      // am=0 is "no amount", not a fixed ₹0.
      expect(p.fixedAmount, isFalse);
    });

    test('a name with a plus sign for a space, and a stray %', () {
      final p = parseUpiQr('upi://pay?pa=a1@paytm&pn=Tea+Stall%')!;
      expect(p.name, 'Tea+Stall%');
      final q = parseUpiQr('upi://pay?pa=a1@paytm&pn=Tea+Stall')!;
      expect(q.name, 'Tea Stall');
    });

    test('no name: shows the UPI id', () {
      final p = parseUpiQr('upi://pay?pa=9876543210@upi')!;
      expect(p.name, isNull);
      expect(p.displayName, '9876543210@upi');
    });

    test('anything else is not a UPI payment QR', () {
      for (final raw in [
        'https://example.com/pay?pa=x@ybl',
        'upi://mandate?pa=x@ybl',
        'upi://pay?pn=No%20Id',
        'upi://pay?pa=not-an-id',
        'WIFI:S:Home;T:WPA;P:secret;;',
        'srisai@okaxis',
        '',
      ]) {
        expect(parseUpiQr(raw), isNull, reason: raw);
      }
    });
  });

  group('upiPayUri', () {
    test('adds the typed amount, INR and the note; keeps merchant fields', () {
      final p = parseUpiQr(
        'upi://pay?pa=srisai.stores@okaxis&pn=Sri%20Sai%20Stores&mc=5411',
      )!;
      final uri = upiPayUri(p, amount: d('250'), note: 'Groceries');
      final q = uri.queryParameters;
      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(q['pa'], 'srisai.stores@okaxis');
      expect(q['pn'], 'Sri Sai Stores');
      expect(q['mc'], '5411');
      expect(q['am'], '250.00');
      expect(q['cu'], 'INR');
      expect(q['tn'], 'Groceries');
      // Spaces travel as %20, which every UPI app reads.
      expect(uri.toString(), contains('pn=Sri%20Sai%20Stores'));
    });

    test('a fixed amount and the QR\'s own note are left alone', () {
      final p = parseUpiQr(
        'upi://pay?pa=canteen@ybl&pn=Canteen&am=45.50&tn=Lunch',
      )!;
      final q = upiPayUri(p, amount: d('999'), note: 'Mine').queryParameters;
      expect(q['am'], '45.50');
      expect(q['tn'], 'Lunch');
    });

    test('a blank note adds no tn', () {
      final p = parseUpiQr('upi://pay?pa=a1@paytm')!;
      expect(
        upiPayUri(p, amount: d('10'), note: '  ').queryParameters,
        isNot(contains('tn')),
      );
    });
  });

  group('parseUpiResponse', () {
    test('success, with the bank reference preferred', () {
      final o = parseUpiResponse(
        'txnId=PTM123&responseCode=00&Status=SUCCESS&txnRef=FR1'
        '&ApprovalRefNo=432198765432',
      );
      expect(o.status, UpiStatus.success);
      expect(o.txnId, 'PTM123');
      expect(o.reference, '432198765432');
    });

    test('lower-case keys, and no approval number', () {
      final o = parseUpiResponse('txnid=ICI99&status=success');
      expect(o.status, UpiStatus.success);
      expect(o.reference, 'ICI99');
    });

    test('submitted / pending, failure', () {
      expect(
        parseUpiResponse('Status=SUBMITTED&txnId=1').status,
        UpiStatus.submitted,
      );
      expect(parseUpiResponse('status=PENDING').status, UpiStatus.submitted);
      expect(parseUpiResponse('Status=FAILURE').status, UpiStatus.failure);
      expect(parseUpiResponse('Status=Failed').status, UpiStatus.failure);
    });

    test('no answer is unknown, never failure', () {
      expect(parseUpiResponse(null).status, UpiStatus.unknown);
      expect(parseUpiResponse('').status, UpiStatus.unknown);
      expect(parseUpiResponse('responseCode=ZD').status, UpiStatus.unknown);
    });

    test('"null" from an app is no reference', () {
      final o = parseUpiResponse('Status=SUCCESS&txnId=null&ApprovalRefNo=');
      expect(o.reference, isNull);
    });
  });
}
