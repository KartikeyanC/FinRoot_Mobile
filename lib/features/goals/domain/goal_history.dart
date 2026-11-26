import 'package:decimal/decimal.dart';

import '../../../core/money/money.dart';

/// One line of a goal's contribution history — a row of the shared
/// `goal_contributions` table (web migration 20261126140000), written by the
/// `goal_contribute` RPC on every call that actually moved money. [amount] is
/// what was APPLIED (negative = taken back), so the history always adds up to
/// what moved. A log, never a ledger: `goals.current_amount` stays the figure
/// of record.
class GoalContributionEntry {
  const GoalContributionEntry({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.contributedAt,
    this.note,
  });

  factory GoalContributionEntry.fromRow(
    Map<String, dynamic> r, {
    String currency = 'INR',
  }) {
    final note = r['note'];
    final when = r['contributed_at'] ?? r['created_at'];
    return GoalContributionEntry(
      id: r['id'].toString(),
      goalId: r['goal_id'].toString(),
      amount: Money(
        Money.parse((r['amount'] ?? 0).toString()).amount,
        currency,
      ),
      note: note is String && note.trim().isNotEmpty ? note : null,
      contributedAt:
          DateTime.tryParse(when?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String goalId;
  final Money amount;
  final String? note;
  final DateTime contributedAt;

  bool get isWithdrawal => amount.amount < Decimal.zero;
}

/// A goal's history as the phone can see it. [missing] is true while the
/// `goal_contributions` migration is not applied on the server — the UI then
/// shows a hint instead of an error.
class GoalHistory {
  const GoalHistory(this.entries) : missing = false;
  const GoalHistory.missing() : entries = const [], missing = true;

  final List<GoalContributionEntry> entries;
  final bool missing;
}

/// Longest note the server keeps (`CHECK length(note) <= 200`).
const int kGoalNoteMax = 200;

/// Trimmed, capped note; null when empty.
String? cleanGoalNote(String? note) {
  final t = (note ?? '').trim();
  if (t.isEmpty) return null;
  return t.length > kGoalNoteMax ? t.substring(0, kGoalNoteMax) : t;
}

/// The table or the 3-argument `goal_contribute` overload does not exist yet
/// (the web's `isGoalHistoryMissing`): 42P01 relation, PGRST205 table not in
/// the schema cache, PGRST202 no function with those arguments.
bool isGoalHistoryMissingError(String? code, String? message) {
  if (code == '42P01' || code == 'PGRST205' || code == 'PGRST202') {
    return true;
  }
  final m = message ?? '';
  return RegExp('goal_contribut', caseSensitive: false).hasMatch(m) &&
      RegExp(
        'does not exist|schema cache|could not find',
        caseSensitive: false,
      ).hasMatch(m);
}

const String kGoalHistoryMissingMessage =
    'History starts once the workspace owner runs the database update.';

/* ------------------------- editing a history entry ------------------------- */

const String kGoalHistoryEditMissingMessage =
    'Editing history needs the database update (migration '
    '20261126160000_goal_contribution_edits.sql). Ask the workspace owner to '
    'run it; until then, undo a deposit with Take back.';

/// `goal_contribution_update` / `_delete` don't exist yet: migration
/// 20261126160000 hasn't run (web `isGoalHistoryEditMissing`).
bool isGoalHistoryEditMissingError(String? code, String? message) {
  if (code == 'PGRST202' || code == '42883') return true;
  final m = message ?? '';
  return RegExp(
        'goal_contribution_(update|delete)',
        caseSensitive: false,
      ).hasMatch(m) &&
      RegExp(
        'does not exist|schema cache|could not find',
        caseSensitive: false,
      ).hasMatch(m);
}

/// Why an edit (or, with [deleting], a delete) of a history entry can't be
/// saved, or null if it can — the server's rules (web
/// `historyChangeProblem`): an entry is never zero, its date is not in the
/// future, and the goal's saved amount moves by the difference without going
/// below zero or past the target. The server re-checks under a lock.
String? historyChangeProblem({
  required double original,
  required double next,
  required double currentAmount,
  required double targetAmount,
  DateTime? date,
  bool deleting = false,
  DateTime? today,
}) {
  if (!deleting && (!next.isFinite || next == 0)) {
    return 'Enter an amount. To remove the entry, delete it.';
  }
  if (date != null) {
    final t = today ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    if (day.isAfter(DateTime(t.year, t.month, t.day))) {
      return "The date can't be in the future";
    }
  }
  final after =
      ((currentAmount - original + (deleting ? 0 : next)) * 100).round() / 100;
  if (after < 0) {
    return 'That would take the goal below zero (it holds '
        '${_plain(currentAmount)})';
  }
  if (after > targetAmount) {
    return 'That would take the goal past its target of '
        '${_plain(targetAmount)}';
  }
  return null;
}

String _plain(double n) =>
    n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
