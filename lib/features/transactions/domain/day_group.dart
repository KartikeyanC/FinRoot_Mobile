import 'transaction.dart';

/// A day's worth of ledger rows, for the grouped Transactions list.
class DayGroup {
  const DayGroup({required this.day, required this.items});

  /// Local calendar date (time zeroed).
  final DateTime day;
  final List<TransactionEntity> items;
}

/// Split a newest-first transaction list into newest-first day groups. Input
/// order is preserved within each group.
List<DayGroup> groupByDay(List<TransactionEntity> txns) {
  final groups = <DayGroup>[];
  DateTime? currentDay;
  var bucket = <TransactionEntity>[];

  for (final txn in txns) {
    final local = txn.occurredAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    if (currentDay == null || day != currentDay) {
      if (currentDay != null) {
        groups.add(DayGroup(day: currentDay, items: bucket));
      }
      currentDay = day;
      bucket = <TransactionEntity>[];
    }
    bucket.add(txn);
  }
  if (currentDay != null) {
    groups.add(DayGroup(day: currentDay, items: bucket));
  }
  return groups;
}
