import 'dart:math';

import 'package:finroot_mobile/features/sync/domain/backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const b = Backoff(); // base 4s, max 30min, factor 2

  test('attempt 0 is immediate', () {
    expect(b.delayFor(0), Duration.zero);
    expect(b.ceilingFor(0), Duration.zero);
  });

  test('ceiling grows exponentially then caps at max', () {
    expect(b.ceilingFor(1), const Duration(seconds: 4));
    expect(b.ceilingFor(2), const Duration(seconds: 8));
    expect(b.ceilingFor(3), const Duration(seconds: 16));
    expect(b.ceilingFor(10), const Duration(minutes: 30)); // capped
  });

  test('jittered delay stays within [0, ceiling]', () {
    final rng = Random(42);
    for (var attempt = 1; attempt <= 8; attempt++) {
      final d = b.delayFor(attempt, random: rng);
      expect(d, greaterThanOrEqualTo(Duration.zero));
      expect(d, lessThanOrEqualTo(b.ceilingFor(attempt)));
    }
  });
}
