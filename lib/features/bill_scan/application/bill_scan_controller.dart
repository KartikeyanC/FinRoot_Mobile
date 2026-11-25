import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/providers/providers.dart';
import '../../quick_add/application/quick_add_controller.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/receipt_camera.dart';
import '../data/receipt_scan_gateway.dart';
import '../domain/captured_image.dart';
import '../domain/scan_result.dart';
import '../domain/scanned_row.dart';

enum BillScanPhase { staging, scanning, review }

class BillScanState {
  const BillScanState({
    this.phase = BillScanPhase.staging,
    this.images = const [],
    this.result,
    this.mode = ScanMode.lumpsum,
    this.rows = const [],
    this.error,
    this.rejected = const [],
    this.saveMode = BillSaveMode.single,
    this.people = 1,
  });

  final BillScanPhase phase;
  final List<CapturedImage> images;
  final ScanResult? result;
  final ScanMode mode;
  final List<ScannedRow> rows;

  /// Transient — the last failure, shown then cleared on the next action.
  final Failure? error;

  /// Transient — why the last add dropped some images.
  final List<RejectedImage> rejected;

  /// One expense, or one per category (line items only).
  final BillSaveMode saveMode;

  /// How many people share the bill; above 1 only your share is logged.
  final int people;

  bool get canScan => images.isNotEmpty && phase != BillScanPhase.scanning;

  ApprovalTransaction? get approval =>
      result == null ? null : buildApprovalTransaction(rows, result!.merchant);

  /// The expenses Approve will log, with the split options applied. Per
  /// category only means something with line items.
  List<ApprovalTransaction> get planned => result == null
      ? const []
      : planBillExpenses(
          rows,
          result!.merchant,
          mode: mode == ScanMode.lineItem ? saveMode : BillSaveMode.single,
          people: people,
        );

  Reconciliation? get reconciliation =>
      result == null ? null : Reconciliation.of(rows, result!.total);

  BillScanState copyWith({
    BillScanPhase? phase,
    List<CapturedImage>? images,
    ScanResult? result,
    ScanMode? mode,
    List<ScannedRow>? rows,
    Failure? error,
    List<RejectedImage>? rejected,
    BillSaveMode? saveMode,
    int? people,
    bool clearError = false,
    bool clearResult = false,
  }) => BillScanState(
    phase: phase ?? this.phase,
    images: images ?? this.images,
    result: clearResult ? null : (result ?? this.result),
    mode: mode ?? this.mode,
    rows: rows ?? this.rows,
    error: clearError ? null : (error ?? this.error),
    rejected: rejected ?? this.rejected,
    saveMode: saveMode ?? this.saveMode,
    people: people ?? this.people,
  );
}

/// Drives the bill-scan flow: stage photos → `scan-receipt` → review / edit →
/// approve (one expense via the normal Quick Add write path).
class BillScanController extends Notifier<BillScanState> {
  @override
  BillScanState build() => const BillScanState();

  ReceiptCamera get _camera => ref.read(receiptCameraProvider);
  ReceiptScanGateway get _gateway => ref.read(receiptScanGatewayProvider);

  Future<void> captureFromCamera() => _add(() async {
    final img = await _camera.capture();
    return img == null ? const [] : [img];
  });

  Future<void> addFromGallery() => _add(_camera.pickFromGallery);

  Future<void> _add(Future<List<CapturedImage>> Function() pick) async {
    List<CapturedImage> picked;
    try {
      picked = await pick();
    } on Failure catch (f) {
      state = state.copyWith(error: f);
      return;
    } catch (_) {
      state = state.copyWith(error: const UnexpectedFailure());
      return;
    }
    if (picked.isEmpty) {
      state = state.copyWith(clearError: true, rejected: const []);
      return;
    }
    final v = validateNewImages(state.images.length, picked);
    state = state.copyWith(
      images: [...state.images, ...v.accepted],
      rejected: v.rejected,
      clearError: true,
      // A new photo invalidates a prior scan.
      clearResult: true,
      rows: const [],
      phase: BillScanPhase.staging,
    );
  }

  void removeImage(String id) {
    state = state.copyWith(
      images: [
        for (final i in state.images)
          if (i.id != id) i,
      ],
      clearResult: true,
      rows: const [],
      phase: BillScanPhase.staging,
      rejected: const [],
    );
  }

  void reset() => state = const BillScanState();

  Future<void> scan() async {
    if (!state.canScan) return;
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) {
      state = state.copyWith(error: AuthFailure.sessionExpired());
      return;
    }
    if (!ref.read(isOnlineProvider)) {
      state = state.copyWith(error: const NetworkFailure());
      return;
    }
    state = state.copyWith(
      phase: BillScanPhase.scanning,
      clearError: true,
      rejected: const [],
    );
    try {
      final result = await _gateway.scan(tenantId, state.images);
      final today = DateTime.now();
      state = state.copyWith(
        phase: BillScanPhase.review,
        result: result,
        rows: rowsFromScanResult(result, state.mode, today),
      );
    } on Failure catch (f) {
      state = state.copyWith(phase: BillScanPhase.staging, error: f);
    }
  }

  void setMode(ScanMode mode) {
    final result = state.result;
    if (result == null || mode == state.mode) return;
    final today = state.rows.isNotEmpty
        ? state.rows.first.date
        : DateTime.now();
    state = state.copyWith(
      mode: mode,
      // Keep the date and time already chosen on the review screen.
      rows: [
        for (final r in rowsFromScanResult(result, mode, today))
          r.copyWith(date: today),
      ],
    );
  }

  /// Set the date and time the approved expense is logged at (all rows share
  /// one moment — the ledger entry is a single transaction).
  void setDateTime(DateTime when) {
    state = state.copyWith(
      rows: [for (final r in state.rows) r.copyWith(date: when)],
    );
  }

  void editRow(String id, {String? name, String? category, Money? amount}) {
    state = state.copyWith(
      rows: [
        for (final r in state.rows)
          if (r.id == id)
            r.copyWith(name: name, category: category, amount: amount)
          else
            r,
      ],
    );
  }

  void setSaveMode(BillSaveMode m) => state = state.copyWith(saveMode: m);

  void setPeople(int n) => state = state.copyWith(people: n.clamp(1, 20));

  void removeRow(String id) {
    state = state.copyWith(
      rows: [
        for (final r in state.rows)
          if (r.id != id) r,
      ],
    );
  }

  /// Log the reviewed receipt through the normal Quick Add path (cache +
  /// outbox, offline-safe): one expense, one per category, or your share.
  /// Returns the first new transaction id.
  Future<String> approve() async {
    final planned = state.planned;
    if (planned.isEmpty || !planned.every((p) => p.amount.isPositive)) {
      throw const ValidationFailure('Nothing to log — add or keep a line.');
    }
    state = state.copyWith(clearError: true);
    final quickAdd = ref.read(quickAddControllerProvider);
    final ids = <String>[];
    try {
      for (final p in planned) {
        ids.add(
          await quickAdd.submit(
            kind: QuickAddKind.expense,
            amount: p.amount,
            occurredAt: p.date,
            category: p.category,
            note: p.description,
          ),
        );
      }
      reset();
      return ids.first;
    } on Failure catch (f) {
      // Entries already logged stay logged; keep only the rest to retry.
      if (ids.isNotEmpty) {
        state = state.copyWith(
          error: ValidationFailure(
            '${ids.length} of ${planned.length} logged. ${f.message}',
          ),
        );
      } else {
        state = state.copyWith(error: f);
      }
      rethrow;
    }
  }
}

final billScanControllerProvider =
    NotifierProvider<BillScanController, BillScanState>(
      BillScanController.new,
      name: 'billScanController',
    );
