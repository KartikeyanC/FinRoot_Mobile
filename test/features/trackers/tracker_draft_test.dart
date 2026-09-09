import 'package:finroot_mobile/features/trackers/domain/tracker_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('name required, ≤ 80 chars', () {
    expect(TrackerValidators.name(''), isNotNull);
    expect(TrackerValidators.name('  '), isNotNull);
    expect(TrackerValidators.name('x' * 81), isNotNull);
    expect(TrackerValidators.name('Dubai Trip'), isNull);
  });

  test('budget optional, non-negative, bounded', () {
    expect(TrackerValidators.budget(null), isNull);
    expect(TrackerValidators.budget(''), isNull);
    expect(TrackerValidators.budget('-1'), isNotNull);
    expect(TrackerValidators.budget('junk'), isNotNull);
    expect(TrackerValidators.budget('4,00,000'), isNull);
    expect(TrackerValidators.budget('1000000000000000'), isNotNull);
  });

  test('description ≤ 500 chars', () {
    expect(TrackerValidators.description('x' * 500), isNull);
    expect(TrackerValidators.description('x' * 501), isNotNull);
  });

  test('end date cannot precede start date', () {
    final start = DateTime(2026, 3, 10);
    expect(TrackerValidators.dateRange(start: start), isNull);
    expect(
      TrackerValidators.dateRange(start: start, end: DateTime(2026, 3, 9)),
      isNotNull,
    );
    expect(
      TrackerValidators.dateRange(start: start, end: DateTime(2026, 3, 10)),
      isNull,
    );
  });

  test('status round-trips and falls back to active', () {
    expect(TrackerStatus.fromWire('completed'), TrackerStatus.completed);
    expect(TrackerStatus.fromWire('nonsense'), TrackerStatus.active);
  });
}
