import 'package:finroot_mobile/features/home/domain/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String at(int hour, [int minute = 0]) =>
      timeGreeting(DateTime(2026, 11, 25, hour, minute));

  test('morning, afternoon, evening and night', () {
    expect(at(5), 'Good morning');
    expect(at(11, 59), 'Good morning');
    expect(at(12), 'Good afternoon');
    expect(at(16, 59), 'Good afternoon');
    expect(at(17), 'Good evening');
    expect(at(20, 59), 'Good evening');
    expect(at(21), 'Good night');
    expect(at(23, 59), 'Good night');
    expect(at(0), 'Good night');
    expect(at(2), 'Good night'); // not "Good morning" at 2 AM
    expect(at(4, 59), 'Good night');
  });
}
