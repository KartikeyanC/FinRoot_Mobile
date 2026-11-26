import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/split/data/split_dues_gateway.dart';
import 'package:finroot_mobile/features/split/domain/split_dues.dart';

/// In-memory `split_dues`; `missing` behaves like the unapplied migration.
class FakeSplitDuesGateway implements SplitDuesGateway {
  FakeSplitDuesGateway({List<SplitDue>? dues, this.missing = false})
    : dues = [...?dues];

  final List<SplitDue> dues;
  bool missing;
  final inserted = <NewSplitDue>[];
  final settled = <(String, double?)>[];

  @override
  Future<List<SplitDue>> list(String tenantId) async {
    if (missing) throw const SplitDuesMissing();
    return List.of(dues);
  }

  @override
  Future<void> insert(String tenantId, List<NewSplitDue> rows) async {
    if (missing) throw const SplitDuesMissing();
    inserted.addAll(rows);
  }

  @override
  Future<void> settle(String id, {double? amount}) async {
    if (missing) throw const SplitDuesMissing();
    settled.add((id, amount));
  }
}

/// Records what Quick Add was asked to save.
class FakeQuickAddController extends QuickAddController {
  FakeQuickAddController(super.ref);

  final calls =
      <({Money amount, String? note, String? editingId, String? category})>[];

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
    calls.add((
      amount: amount,
      note: note,
      editingId: editingId,
      category: category,
    ));
    return editingId ?? 'tx-new';
  }
}
