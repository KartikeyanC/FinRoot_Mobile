import 'package:flutter/material.dart';

import '../../../core/money/money.dart';

/// The fields the mobile tracker form sets. `currency` stays INR (V1),
/// `user_id` / `tenant_id` are set by the write path, lifecycle timestamps by
/// the status actions.
class TrackerDraft {
  const TrackerDraft({
    required this.name,
    required this.type,
    required this.startDate,
    this.endDate,
    this.budget,
    this.description,
  });

  final String name;
  final String type;
  final DateTime startDate;
  final DateTime? endDate;
  final Money? budget;
  final String? description;
}

/// `trackers.status` — three states (web `TrackerStatus`).
enum TrackerStatus {
  active,
  completed,
  archived;

  static TrackerStatus fromWire(String v) =>
      TrackerStatus.values.firstWhere((s) => s.name == v, orElse: () => active);

  String get label => switch (this) {
    active => 'Active',
    completed => 'Completed',
    archived => 'Archived',
  };
}

/// Icon per tracker type — mirrors web `trackerMeta.ts`, falling back to the
/// Custom icon for a type a newer client wrote.
IconData trackerTypeIcon(String type) => switch (type) {
  'Home Construction' => Icons.home_outlined,
  'Travel' => Icons.flight_takeoff_outlined,
  'Wedding' => Icons.favorite_outline,
  'Vehicle' => Icons.directions_car_outlined,
  'Education' => Icons.school_outlined,
  'Business Project' => Icons.work_outline,
  'Event' => Icons.celebration_outlined,
  _ => Icons.folder_open_outlined,
};

abstract final class TrackerValidators {
  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Give your tracker a name';
    if (v.length > 80) return 'That name is too long';
    return null;
  }

  static String? budget(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;
    final money = Money.tryParse(raw);
    if (money == null) return 'Enter a valid amount';
    if (money.isNegative) return 'A budget cannot be negative';
    if (money > Money.parse('999999999999.99')) {
      return 'That budget is too large';
    }
    return null;
  }

  static String? description(String? value) {
    if (value != null && value.trim().length > 500) {
      return 'Keep the description under 500 characters';
    }
    return null;
  }

  /// End date, when set, must not precede the start.
  static String? dateRange({required DateTime start, DateTime? end}) {
    if (end == null) return null;
    final e = DateTime(end.year, end.month, end.day);
    final s = DateTime(start.year, start.month, start.day);
    if (e.isBefore(s)) return 'The end date is before the start date';
    return null;
  }
}
