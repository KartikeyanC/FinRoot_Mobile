import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failure.dart';
import '../../core/providers/providers.dart';
import '../../domain/constants.dart';
import '../menus/application/menu_providers.dart';
import '../reminders/application/reminders_providers.dart';
import '../workspace/application/workspace_providers.dart';
import 'debt_plan.dart';
import 'debts.dart';

/// Add, edit and delete debts — what the web's TransactionDialog ("this is a
/// debt") and DebtLedger do, plus an edit the web doesn't have yet.
///
/// A debt's EMI reminders move with it: added with the debt, rebuilt when its
/// lender or schedule changes, and removed with it (completed ones stay as
/// history, as on the web). Online only; owners and admins only (RLS).
class DebtEditor {
  DebtEditor(this._ref, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Ref _ref;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  DebtsGateway get _gw => _ref.read(debtsGatewayProvider);

  bool get _remindersOn =>
      _ref.read(menuStatusProvider(FeatureMenu.reminders)) != MenuStatus.locked;

  String _check() {
    final tenantId = _ref.read(currentTenantIdProvider);
    if (tenantId == null) throw AuthFailure.sessionExpired();
    final role = _ref.read(currentRoleProvider);
    if (role != null && !role.canWrite) {
      throw const PermissionFailure(
        message: 'Your role in this workspace is view-only.',
      );
    }
    if (!_ref.read(isOnlineProvider)) throw const NetworkFailure();
    return tenantId;
  }

  void _refresh() {
    _ref
      ..invalidate(debtsProvider)
      ..invalidate(remindersProvider);
  }

  /// Saves a new debt with its EMI schedule (and reminders).
  Future<void> add(DebtDraft d) async {
    final tenantId = _check();
    var plan = planNewDebt(
      tenantId: tenantId,
      d: d,
      withReminders: _remindersOn,
      now: _clock(),
    );
    var reminderIds = [for (final r in plan.reminders) r['id'] as String];
    if (plan.reminders.isNotEmpty) {
      try {
        await _gw.insertReminders(plan.reminders);
      } on Failure {
        // Reminders refused (menu or role): save the debt without them.
        plan = planNewDebt(
          tenantId: tenantId,
          d: d,
          withReminders: false,
          now: _clock(),
          debtId: plan.debt['id'] as String,
        );
        reminderIds = const [];
      }
    }
    try {
      await _gw.insertDebt(plan.debt);
    } on Failure {
      if (reminderIds.isNotEmpty) {
        try {
          await _gw.deleteReminders(tenantId, reminderIds);
        } on Failure {
          // best effort
        }
      }
      rethrow;
    }
    _refresh();
  }

  /// Saves changes. The schedule (amount, months, first date) can change only
  /// while no EMI has been paid; the lender, category and notes always can.
  Future<void> edit(Debt existing, DebtDraft d) async {
    final tenantId = _check();
    final firstDue =
        existing.firstDue ?? existing.installments.firstOrNull?.dueDate;
    final scheduleChanged =
        d.total != existing.total ||
        d.months != existing.duration ||
        firstDue == null ||
        isoDay(d.firstDue) != isoDay(firstDue);
    if (scheduleChanged && existing.paidCount > 0) {
      throw const ValidationFailure(
        'Some EMIs are already paid, so the amount and dates can\'t change. '
        'Delete the debt and add it again to start a new schedule.',
      );
    }

    // Only the category or notes changed: the schedule and its reminders stay.
    if (!scheduleChanged && d.lender.trim() == existing.lender.trim()) {
      await _gw.updateDebt(tenantId, existing.id, debtFields(d));
      _refresh();
      return;
    }

    final base = scheduleChanged
        ? buildInstallments(d.total, d.months, d.firstDue)
        : [
            for (final i in existing.installments)
              Map<String, dynamic>.of(i.raw),
          ];

    final now = _clock();
    final reminders = <Map<String, dynamic>>[];
    final withReminders = _remindersOn;
    final installments = [
      for (final inst in base)
        if (inst['status'] == 'paid')
          inst
        else if (withReminders)
          () {
            final rid = _uuid.v4();
            reminders.add(
              emiReminderRow(
                id: rid,
                tenantId: tenantId,
                debtId: existing.id,
                d: d,
                installment: inst,
                now: now,
              ),
            );
            return {...inst, 'reminderId': rid};
          }()
        else
          ({...inst}..remove('reminderId')),
    ];

    // Replace the open reminders with ones that match the saved debt.
    try {
      await _gw.deleteOpenReminders(tenantId, existing.id);
      await _gw.insertReminders(reminders);
    } on Failure {
      for (final i in installments) {
        if (i['status'] != 'paid') i.remove('reminderId');
      }
    }
    await _gw.updateDebt(tenantId, existing.id, {
      ...debtFields(d),
      'installments': installments,
    });
    _refresh();
  }

  /// Changes one EMI: its [amount], and/or whether it is [paid]. The debt's
  /// total and monthly follow its EMIs, and the EMI's reminder follows
  /// (best effort: amount, and completed once paid).
  Future<void> updateInstallment(
    Debt debt,
    int month, {
    double? amount,
    bool? paid,
  }) async {
    final tenantId = _check();
    if (amount != null && (!amount.isFinite || amount <= 0)) {
      throw const ValidationFailure('Enter the EMI amount');
    }
    var list = [
      for (final i in debt.installments) Map<String, dynamic>.of(i.raw),
    ];
    if (amount != null) list = withInstallmentAmount(list, month, amount);
    if (paid != null) {
      list = withInstallmentPaid(list, month, paid: paid, now: _clock());
    }
    final totals = debtTotals(list);
    await _gw.updateDebt(tenantId, debt.id, {
      'installments': list,
      'total_amount': totals.total,
      'monthly': totals.monthly,
    });

    final changed = list.where((i) => i['month'] == month).firstOrNull;
    final reminderId = changed?['reminderId'] as String?;
    if (reminderId != null && changed != null) {
      try {
        await _gw.updateReminder(tenantId, reminderId, {
          if (amount != null) 'amount': changed['amount'],
          if (paid != null) 'status': paid ? 'completed' : 'scheduled',
        });
      } on Failure {
        // The debt is right; a stale reminder is only a nudge.
      }
    }
    _refresh();
  }

  /// Deletes the debt and its upcoming EMI reminders.
  Future<void> delete(Debt debt) async {
    final tenantId = _check();
    try {
      await _gw.deleteOpenReminders(tenantId, debt.id);
    } on Failure {
      // Reminders may be off for this member; the debt still goes.
    }
    await _gw.deleteDebt(tenantId, debt.id);
    _refresh();
  }
}

final debtEditorProvider = Provider<DebtEditor>(
  (ref) => DebtEditor(ref),
  name: 'debtEditor',
);
