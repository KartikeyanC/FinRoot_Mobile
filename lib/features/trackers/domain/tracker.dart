import '../../../core/money/money.dart';

/// A tracker as the Home feed needs it — name, dates and the server-set budget.
/// Spend / progress is server-derived and arrives with the tracker feature
/// (M9); M6 only lists the active ones (ADR-0006, ADR-0010).
class TrackerEntity {
  const TrackerEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.startDate,
    this.endDate,
    this.budget,
    this.description,
    this.status = 'active',
  });

  final String id;
  final String name;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;

  /// INR-anchored, exactly as the server stores it. Null when the tracker has
  /// no budget set.
  final Money? budget;
  final String? description;
  final String status;

  bool get isActive => status == 'active';
}
