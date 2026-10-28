import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/payment_capture/application/payment_capture_controller.dart';
import 'package:finroot_mobile/features/payment_capture/data/payment_capture_gateway.dart';
import 'package:finroot_mobile/features/payment_capture/domain/detected_payment.dart';
import 'package:finroot_mobile/features/payment_capture/presentation/detected_payments_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeGateway implements PaymentCaptureGateway {
  FakeGateway({
    this.enabled = true,
    this.hasAccess = true,
    List<PaymentNotice>? notices,
  }) : notices = notices ?? [];

  bool enabled;
  bool hasAccess;
  bool sms = false;
  int settingsOpened = 0;
  final List<PaymentNotice> notices;

  @override
  Future<PaymentCaptureStatus> status() async => PaymentCaptureStatus(
    supported: true,
    enabled: enabled,
    smsEnabled: sms,
    hasAccess: hasAccess,
  );

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> setSmsEnabled(bool on) async => sms = on;

  @override
  Future<void> openAccessSettings() async => settingsOpened++;

  @override
  Future<List<PaymentNotice>> pending() async => List.of(notices);

  @override
  Future<void> remove(List<String> ids) async =>
      notices.removeWhere((n) => ids.contains(n.id));
}

PaymentNotice _gpay(String id, String title) => PaymentNotice(
  id: id,
  packageName: 'com.google.android.apps.nbu.paisa.user',
  title: title,
  text: '',
  postedAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

Future<void> _pump(WidgetTester tester, FakeGateway gw) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        paymentCaptureGatewayProvider.overrideWithValue(gw),
        recentLedgerForMatchingProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
        currentTenantIdProvider.overrideWithValue('t1'),
        currentUserIdProvider.overrideWithValue('u1'),
        workspaceAccountsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const DetectedPaymentsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('off: only the switch, turning it on asks for access', (
    tester,
  ) async {
    final gw = FakeGateway(enabled: false, hasAccess: false);
    await _pump(tester, gw);
    expect(find.text('Detect my payments'), findsOneWidget);
    expect(find.text('To review'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(gw.enabled, isTrue);
    expect(gw.settingsOpened, 1, reason: 'sent to Notification access');
    expect(find.text('Open Notification access'), findsOneWidget);
    expect(find.text('Include bank SMS alerts'), findsOneWidget);
  });

  testWidgets('lists payments; junk notices are dropped; Ignore removes', (
    tester,
  ) async {
    final gw = FakeGateway(
      notices: [
        _gpay('a', '₹500 paid to Ravi Kumar'),
        _gpay('b', 'Your OTP is 123456 for payment of ₹10'),
      ],
    );
    await _pump(tester, gw);

    expect(find.text('To review (1)'), findsOneWidget);
    expect(find.text('Paid to Ravi Kumar'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
    expect(gw.notices.map((n) => n.id), ['a'], reason: 'OTP notice purged');

    await tester.tap(find.text('Ignore'));
    await tester.pumpAndSettle();
    expect(find.text('No new payments'), findsOneWidget);
    expect(gw.notices, isEmpty);
  });

  testWidgets('Add opens Quick Add filled in from the payment', (tester) async {
    final gw = FakeGateway(
      notices: [_gpay('a', '₹1,249.50 paid to Ravi Kumar')],
    );
    await _pump(tester, gw);
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsWidgets);
    expect(find.text('1249.5'), findsOneWidget);
    expect(find.text('Paid to Ravi Kumar'), findsWidgets);
    expect(find.text('UPI'), findsOneWidget);
  });
}
