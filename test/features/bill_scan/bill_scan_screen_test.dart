import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/theme/app_theme.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/bill_scan/data/receipt_camera.dart';
import 'package:finroot_mobile/features/bill_scan/data/receipt_scan_gateway.dart';
import 'package:finroot_mobile/features/bill_scan/domain/captured_image.dart';
import 'package:finroot_mobile/features/bill_scan/domain/scan_result.dart';
import 'package:finroot_mobile/features/bill_scan/presentation/bill_scan_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubCamera implements ReceiptCamera {
  @override
  Future<CapturedImage?> capture() async =>
      CapturedImage(bytes: Uint8List(8), mimeType: 'image/jpeg');
  @override
  Future<List<CapturedImage>> pickFromGallery() async => const [];
}

class _StubGateway implements ReceiptScanGateway {
  @override
  Future<ScanResult> scan(String t, List<CapturedImage> images) async =>
      ScanResult(
        merchant: 'Cafe',
        currency: 'INR',
        total: Money(Decimal.parse('120')),
        items: [
          ScanItem(
            name: 'Coffee',
            qty: 1,
            unit: 'pc',
            amount: Money(Decimal.parse('120')),
            category: 'Food & Dining',
          ),
        ],
        taxLines: const [],
      );
}

Widget _host({MenuStatus menu = MenuStatus.available}) => ProviderScope(
  overrides: [
    currentTenantIdProvider.overrideWithValue('t1'),
    currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
    isOnlineProvider.overrideWithValue(true),
    menuStatusProvider(FeatureMenu.billScan).overrideWithValue(menu),
    receiptCameraProvider.overrideWithValue(_StubCamera()),
    receiptScanGatewayProvider.overrideWithValue(_StubGateway()),
  ],
  child: MaterialApp(theme: AppTheme.light, home: const BillScanScreen()),
);

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('staging shows capture options and empty state', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('No photo yet'), findsOneWidget);
  });

  testWidgets('capture then scan reaches the review screen', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Scan receipt'), findsOneWidget);
    await tester.tap(find.text('Scan receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsWidgets);
    expect(find.textContaining('Log expense'), findsOneWidget);
    expect(find.text('Whole bill'), findsOneWidget);
  });
}
