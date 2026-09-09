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

  Future<String> submit({
    required QuickAddKind kind,
    required Money amount,
    required DateTime occurredAt,
    String? category,
    String? note,
    String? paymentMode,
    String? fromAccountId,
    String? toAccountId,
  }) async {
    final tenantId = _ref.read(currentTenantIdProvider);
    final userId = _ref.read(currentUserIdProvider);
    if (tenantId == null || userId == null) {
      throw AuthFailure.sessionExpired();
    }
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }

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
      accountId: isTransfer ? fromAccountId : null,
      paymentMode: isTransfer ? null : paymentMode,
      transferToAccountId: isTransfer ? toAccountId : null,
    );

    final String id;
    try {
      id = await _ref
          .read(mutationEnqueuerProvider)
          .create(tenantId, userId, draft);
    } catch (error, stack) {
      throw mapError(error, stack);
    }

    // The row is already safely queued; nudge the engine to push it now.
    unawaited(_ref.read(syncEngineProvider.notifier).syncNow());
    return id;
  }
}

final quickAddControllerProvider = Provider<QuickAddController>(
  (ref) => QuickAddController(ref),
  name: 'quickAddController',
);
