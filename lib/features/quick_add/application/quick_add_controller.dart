import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/providers/providers.dart';
import '../../sync/application/mutation_enqueuer.dart';
import '../../sync/application/sync_engine.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/quick_add_draft.dart';

/// Turns a validated Quick Add form into a local write. The write itself never
/// touches the network: [MutationEnqueuer] puts the optimistic row in the cache
/// and the outbox in one transaction (M5), so the new transaction shows on Home
/// immediately with its "Pending" marker and syncs when it can.
///
/// Throws a [Failure] the sheet can show; returns the new transaction id.
class QuickAddController {
  QuickAddController(this._ref);

  final Ref _ref;

  /// Create, or — when [editingId] is set — update. Returns the transaction id.
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
    final tenantId = _requireTenant();
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) throw AuthFailure.sessionExpired();
    _requireWriter();

    final isTransfer = kind == QuickAddKind.transfer;
    final trimmedNote = note?.trim();
    final draft = TransactionDraft(
      type: kind.txnType.wire,
      amount: amount.toStorageString(),
      currency: amount.currency,
      category: isTransfer ? kTransferCategory : category!,
      occurredAt: occurredAt,
      description: (trimmedNote == null || trimmedNote.isEmpty)
          ? null
          : trimmedNote,
      accountId: isTransfer ? fromAccountId : accountId,
      paymentMode: isTransfer ? null : paymentMode,
      transferToAccountId: isTransfer ? toAccountId : null,
    );

    try {
      final enqueuer = _ref.read(mutationEnqueuerProvider);
      if (editingId != null) {
        await enqueuer.update(tenantId, editingId, draft);
        return _afterWrite(editingId);
      }
      return _afterWrite(await enqueuer.create(tenantId, userId, draft));
    } catch (error, stack) {
      if (error is Failure) rethrow;
      throw mapError(error, stack);
    }
  }

  /// Queue a delete for [id] (the cache row is hidden until the server
  /// confirms, so a failed delete can retry — M5 / `MutationEnqueuer`).
  Future<void> deleteTransaction(String id) async {
    final tenantId = _requireTenant();
    _requireWriter();
    try {
      await _ref.read(mutationEnqueuerProvider).delete(tenantId, id);
    } catch (error, stack) {
      if (error is Failure) rethrow;
      throw mapError(error, stack);
    }
    _afterWrite(id);
  }

  String _afterWrite(String id) {
    // The row is already safely queued; nudge the engine to push it now. The
    // summary refetches on its own once the sync completes.
    unawaited(_ref.read(syncEngineProvider.notifier).syncNow());
    return id;
  }

  String _requireTenant() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    return tenantId;
  }

  void _requireWriter() {
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
  }
}

final quickAddControllerProvider = Provider<QuickAddController>(
  (ref) => QuickAddController(ref),
  name: 'quickAddController',
);
