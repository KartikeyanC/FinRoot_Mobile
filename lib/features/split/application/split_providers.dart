import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../quick_add/application/quick_add_controller.dart';
import '../../quick_add/domain/quick_add_draft.dart';
import '../../workspace/application/workspace_providers.dart';
import '../data/split_dues_gateway.dart';
import '../domain/split_dues.dart';

/// Every due in the workspace, newest first. Throws [SplitDuesMissing] until
/// the migration is applied.
final splitDuesProvider = FutureProvider<List<SplitDue>>((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId == null) return const [];
  return ref.watch(splitDuesGatewayProvider).list(tenantId);
}, name: 'splitDues');

void _requireWriter(Ref ref) {
  final role = ref.read(currentRoleProvider);
  if (role != null && !role.canWrite) {
    throw const PermissionFailure(
      message: 'Your role in this workspace is view-only.',
    );
  }
}

/// Records and settles dues.
class SplitDuesController {
  SplitDuesController(this._ref);
  final Ref _ref;

  /// Insert [rows]. Resolves to false (rather than throwing) when the table is
  /// missing, like the web's useRecordSplitDues.
  Future<bool> record(List<NewSplitDue> rows) async {
    if (rows.isEmpty) return true;
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    _requireWriter(_ref);
    try {
      await _ref.read(splitDuesGatewayProvider).insert(tenantId, rows);
    } on SplitDuesMissing {
      return false;
    }
    _ref.invalidate(splitDuesProvider);
    return true;
  }

  /// Settle [id] fully ([amount] null) or partly.
  Future<void> settle(String id, {double? amount}) async {
    _requireWriter(_ref);
    await _ref.read(splitDuesGatewayProvider).settle(id, amount: amount);
    _ref.invalidate(splitDuesProvider);
  }
}

final splitDuesControllerProvider = Provider<SplitDuesController>(
  (ref) => SplitDuesController(ref),
  name: 'splitDuesController',
);

/// What a split save did.
enum SplitSaveOutcome {
  /// Your share posted and every friend's share recorded.
  saved,

  /// Your share posted; `split_dues` is not in the database yet.
  savedWithoutDues,
}

/// The ledger description for a split (web SmartSplit's format).
String splitDescription({
  required String name,
  required double total,
  required double mine,
  required double shared,
  required String currency,
}) {
  final bits = ['you ${MoneyFormat.money(mine, currency: currency)}'];
  if (shared > 0) {
    bits.add(
      'shared ${MoneyFormat.money(shared, currency: currency)} recoverable',
    );
  }
  return '$name • bill ${MoneyFormat.money(total, currency: currency)} '
      'split → ${bits.join(' · ')}';
}

/// Saves a split: YOUR share through the Quick Add controller (create, or
/// update [editingId] — the expense Quick Add just saved), then the friends'
/// shares as `split_dues`.
class SplitWithFriendsController {
  SplitWithFriendsController(this._ref);
  final Ref _ref;

  Future<SplitSaveOutcome> save({
    required List<Allocation> allocations,
    required SplitMode mode,
    required double total,
    required String currency,
    required String paidBy,
    required String category,
    required DateTime occurredAt,
    String? name,
    String? accountId,
    String? paymentMode,
    String? editingId,
  }) async {
    _requireWriter(_ref);
    final mine = myShareOf(allocations, mode, total);
    if (mine <= 0) {
      throw const ValidationFailure('Your share must be more than zero.');
    }
    final label = (name ?? '').trim().isEmpty ? 'Split bill' : name!.trim();
    final shared = allocatedOf(allocations, mode, total) - mine;
    final txId = await _ref
        .read(quickAddControllerProvider)
        .submit(
          kind: QuickAddKind.expense,
          amount: Money.parse(mine.toStringAsFixed(2), currency),
          occurredAt: occurredAt,
          category: category,
          note: splitDescription(
            name: label,
            total: total,
            mine: mine,
            shared: shared,
            currency: currency,
          ),
          paymentMode: paymentMode,
          accountId: accountId,
          editingId: editingId,
        );
    final dues = splitToDues(
      allocations: allocations,
      mode: mode,
      total: total,
      currency: currency,
      paidBy: paidBy,
      note: label,
      sourceId: txId,
    );
    final ok = await _ref.read(splitDuesControllerProvider).record(dues);
    return ok ? SplitSaveOutcome.saved : SplitSaveOutcome.savedWithoutDues;
  }
}

final splitWithFriendsControllerProvider = Provider<SplitWithFriendsController>(
  (ref) => SplitWithFriendsController(ref),
  name: 'splitWithFriendsController',
);
