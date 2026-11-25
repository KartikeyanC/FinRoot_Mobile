import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/features/bill_scan/application/bill_scan_controller.dart';
import 'package:finroot_mobile/features/bill_scan/data/receipt_camera.dart';
import 'package:finroot_mobile/features/bill_scan/data/receipt_scan_gateway.dart';
import 'package:finroot_mobile/features/bill_scan/domain/captured_image.dart';
import 'package:finroot_mobile/features/bill_scan/domain/scan_result.dart';
import 'package:finroot_mobile/features/bill_scan/domain/scanned_row.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Money _inr(String v) => Money(Decimal.parse(v));

CapturedImage _img() =>
    CapturedImage(bytes: Uint8List(16), mimeType: 'image/jpeg');

ScanResult _result() => ScanResult(
  merchant: 'Cafe',
  currency: 'INR',
  date: DateTime(2026, 9, 2),
  total: _inr('300'),
  items: [
    ScanItem(
      name: 'Coffee',
      qty: 2,
      unit: 'pc',
      amount: _inr('200'),
      category: 'Food & Dining',
    ),
    ScanItem(
      name: 'Cake',
      qty: 1,
      unit: 'pc',
      amount: _inr('80'),
      category: 'Food & Dining',
    ),
  ],
  taxLines: [ScanTaxLine(label: 'GST', amount: _inr('20'))],
);

class _FakeCamera implements ReceiptCamera {
  List<CapturedImage> next = [];
  @override
  Future<CapturedImage?> capture() async => next.isEmpty ? null : next.first;
  @override
  Future<List<CapturedImage>> pickFromGallery() async => next;
}

class _FakeScanGateway implements ReceiptScanGateway {
  Object? error;
  ScanResult result = _result();
  int calls = 0;
  @override
  Future<ScanResult> scan(String tenantId, List<CapturedImage> images) async {
    calls++;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeQuickAdd implements QuickAddController {
  final List<Map<String, Object?>> submits = [];
  @override
  Future<String> submit({
    required QuickAddKind kind,
    required Money amount,
    required DateTime occurredAt,
    String? category,
    String? note,
    String? paymentMode,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? editingId,
  }) async {
    submits.add({
      'amount': amount.amount.toString(),
      'category': category,
      'note': note,
    });
    return 'txn-1';
  }

  @override
  Future<void> deleteTransaction(String id) async {}
}

({ProviderContainer c, _FakeCamera cam, _FakeScanGateway gw, _FakeQuickAdd qa})
_setup({bool online = true}) {
  final cam = _FakeCamera();
  final gw = _FakeScanGateway();
  final qa = _FakeQuickAdd();
  final c = ProviderContainer(
    overrides: [
      currentTenantIdProvider.overrideWithValue('t1'),
      isOnlineProvider.overrideWithValue(online),
      receiptCameraProvider.overrideWithValue(cam),
      receiptScanGatewayProvider.overrideWithValue(gw),
      quickAddControllerProvider.overrideWithValue(qa),
    ],
  );
  addTearDown(c.dispose);
  return (c: c, cam: cam, gw: gw, qa: qa);
}

void main() {
  test('camera capture stages an image', () async {
    final s = _setup();
    s.cam.next = [_img()];
    await s.c.read(billScanControllerProvider.notifier).captureFromCamera();
    expect(s.c.read(billScanControllerProvider).images, hasLength(1));
    expect(s.c.read(billScanControllerProvider).canScan, isTrue);
  });

  test('scan moves to review with rows', () async {
    final s = _setup();
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    final st = s.c.read(billScanControllerProvider);
    expect(st.phase, BillScanPhase.review);
    expect(st.mode, ScanMode.lumpsum);
    expect(st.rows, hasLength(1)); // lumpsum
    expect(st.approval!.amount.amount.toDouble(), 300);
  });

  test(
    'switching to line items re-derives rows from the same result',
    () async {
      final s = _setup();
      s.cam.next = [_img()];
      final n = s.c.read(billScanControllerProvider.notifier);
      await n.captureFromCamera();
      await n.scan();
      n.setMode(ScanMode.lineItem);
      final st = s.c.read(billScanControllerProvider);
      expect(st.rows, hasLength(3)); // 2 items + 1 tax
      expect(s.gw.calls, 1); // no re-scan
    },
  );

  test('editRow and removeRow feed the approval total', () async {
    final s = _setup();
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    n.setMode(ScanMode.lineItem);
    final rows = s.c.read(billScanControllerProvider).rows;
    n.editRow(rows[0].id, amount: _inr('150')); // was 200
    n.removeRow(rows.last.id); // drop the 20 tax line
    expect(
      s.c.read(billScanControllerProvider).approval!.amount.amount.toDouble(),
      230, // 150 + 80
    );
  });

  test('approve submits one expense and resets', () async {
    final s = _setup();
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    final id = await n.approve();
    expect(id, 'txn-1');
    expect(s.qa.submits.single['amount'], '300');
    expect(s.qa.submits.single['category'], 'Food & Dining');
    expect(s.c.read(billScanControllerProvider).phase, BillScanPhase.staging);
    expect(s.c.read(billScanControllerProvider).images, isEmpty);
  });

  test('split with people logs only your share', () async {
    final s = _setup();
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    n.setPeople(2);
    await n.approve();
    expect(s.qa.submits.single['amount'], '150');
  });

  test('offline scan is refused', () async {
    final s = _setup(online: false);
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    final st = s.c.read(billScanControllerProvider);
    expect(st.error, isA<NetworkFailure>());
    expect(st.phase, BillScanPhase.staging);
    expect(s.gw.calls, 0);
  });

  test('a scan failure returns to staging with the error', () async {
    final s = _setup();
    s.gw.error = const ValidationFailure('Could not read that receipt.');
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    final st = s.c.read(billScanControllerProvider);
    expect(st.phase, BillScanPhase.staging);
    expect(st.error, isA<ValidationFailure>());
  });

  test('a new photo after a scan invalidates the result', () async {
    final s = _setup();
    s.cam.next = [_img()];
    final n = s.c.read(billScanControllerProvider.notifier);
    await n.captureFromCamera();
    await n.scan();
    expect(s.c.read(billScanControllerProvider).phase, BillScanPhase.review);
    s.cam.next = [_img()];
    await n.captureFromCamera();
    final st = s.c.read(billScanControllerProvider);
    expect(st.phase, BillScanPhase.staging);
    expect(st.result, isNull);
    expect(st.images, hasLength(2));
  });
}
