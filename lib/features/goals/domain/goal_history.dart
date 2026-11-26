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
