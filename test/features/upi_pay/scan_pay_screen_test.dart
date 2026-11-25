import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/upi_pay/application/upi_providers.dart';
import 'package:finroot_mobile/features/upi_pay/data/upi_gateway.dart';
import 'package:finroot_mobile/features/upi_pay/domain/upi_qr.dart';
import 'package:finroot_mobile/features/upi_pay/presentation/scan_pay_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeUpi implements UpiGateway {
  _FakeUpi(this.scans, {this.answer = const NoUpiApp()});

  final List<QrScan> scans;
  final PayResult answer;
  final paid = <Uri>[];

  @override
  Future<QrScan> scanQr() async =>
      scans.isEmpty ? const QrCancelled() : scans.removeAt(0);

  @override
  Future<PayResult> pay(Uri upiLink) async {
    paid.add(upiLink);
    return answer;
  }
}

const _shop = QrScanned(
  'upi://pay?pa=srisai.stores@okaxis&pn=Sri%20Sai%20Stores&mc=5411',
);

Widget _host(_FakeUpi upi, {WorkspaceRole role = WorkspaceRole.owner}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push(ScanPayScreen.route),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: ScanPayScreen.route,
        builder: (_, _) => const ScanPayScreen(),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      upiGatewayProvider.overrideWithValue(upi),
      currentRoleProvider.overrideWithValue(role),
    ],
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _open(
  WidgetTester tester,
  _FakeUpi upi, {
  WorkspaceRole? role,
}) async {
  await tester.pumpWidget(_host(upi, role: role ?? WorkspaceRole.owner));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a shop QR: enter the amount, pay, a failure adds nothing', (
    tester,
  ) async {
    final upi = _FakeUpi([
      _shop,
    ], answer: PayAnswered(parseUpiResponse('Status=FAILURE')));
    await _open(tester, upi);

    expect(find.text('Sri Sai Stores'), findsOneWidget);
    expect(find.text('srisai.stores@okaxis'), findsOneWidget);
    expect(find.text('Enter an amount'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('scan-pay-amount')),
      '250',
    );
    await tester.pump();
    await tester.tap(find.textContaining('Pay ₹250'));
    await tester.pumpAndSettle();

    expect(upi.paid.single.queryParameters['am'], '250.00');
    expect(upi.paid.single.queryParameters['pa'], 'srisai.stores@okaxis');
    expect(find.textContaining('didn\'t go through'), findsOneWidget);
    // Still on the form, to try again.
    expect(find.text('Sri Sai Stores'), findsOneWidget);
  });

  testWidgets('a QR that fixes the amount can\'t be changed', (tester) async {
    final upi = _FakeUpi([
      const QrScanned('upi://pay?pa=canteen@ybl&pn=Canteen&am=45.50'),
    ]);
    await _open(tester, upi);

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('scan-pay-amount')),
    );
    expect(field.readOnly, isTrue);
    expect(field.controller!.text, '45.5');
    expect(find.text('Set by the QR'), findsOneWidget);
    expect(find.textContaining('Pay ₹45.50'), findsOneWidget);
  });

  testWidgets('not a UPI QR: says so and offers another scan', (tester) async {
    final upi = _FakeUpi([const QrScanned('https://example.com'), _shop]);
    await _open(tester, upi);

    expect(find.text('That isn\'t a UPI payment QR'), findsOneWidget);
    await tester.tap(find.text('Scan again'));
    await tester.pumpAndSettle();
    expect(find.text('Sri Sai Stores'), findsOneWidget);
  });

  testWidgets('closing the scanner closes the screen', (tester) async {
    await _open(tester, _FakeUpi([const QrCancelled()]));
    expect(find.byType(ScanPayScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('scanner still downloading: try again later', (tester) async {
    await _open(tester, _FakeUpi([const QrUnavailable(downloading: true)]));
    expect(find.text('The scanner is still downloading'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('no answer from the UPI app: asks before adding anything', (
    tester,
  ) async {
    final upi = _FakeUpi([_shop], answer: PayAnswered(parseUpiResponse(null)));
    await _open(tester, upi);
    await tester.enterText(find.byKey(const ValueKey('scan-pay-amount')), '99');
    await tester.pump();
    await tester.tap(find.textContaining('Pay ₹99'));
    await tester.pumpAndSettle();

    expect(find.text('Did the payment go through?'), findsOneWidget);
    await tester.tap(find.text('It didn\'t'));
    await tester.pumpAndSettle();
    expect(find.text('Did the payment go through?'), findsNothing);
    expect(find.text('Sri Sai Stores'), findsOneWidget);
  });

  testWidgets('no UPI app on the phone', (tester) async {
    final upi = _FakeUpi([_shop]);
    await _open(tester, upi);
    await tester.enterText(find.byKey(const ValueKey('scan-pay-amount')), '10');
    await tester.pump();
    await tester.tap(find.textContaining('Pay ₹10'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No UPI app on this phone'), findsOneWidget);
  });

  testWidgets('a viewer can pay, but nothing is recorded', (tester) async {
    final upi = _FakeUpi([
      _shop,
    ], answer: PayAnswered(parseUpiResponse('Status=SUCCESS&txnId=T1')));
    await _open(tester, upi, role: WorkspaceRole.viewer);
    await tester.enterText(find.byKey(const ValueKey('scan-pay-amount')), '20');
    await tester.pump();
    await tester.tap(find.textContaining('Pay ₹20'));
    await tester.pumpAndSettle();

    expect(find.textContaining('can\'t add expenses'), findsOneWidget);
    expect(find.byType(ScanPayScreen), findsNothing);
  });
}
