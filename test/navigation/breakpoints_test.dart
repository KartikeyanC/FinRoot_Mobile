import 'package:finroot_mobile/design/tokens/app_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('window size class thresholds', () {
    expect(AppBreakpoints.fromWidth(360), WindowSize.compact);
    expect(AppBreakpoints.fromWidth(599), WindowSize.compact);
    expect(AppBreakpoints.fromWidth(600), WindowSize.medium);
    expect(AppBreakpoints.fromWidth(839), WindowSize.medium);
    expect(AppBreakpoints.fromWidth(840), WindowSize.expanded);
    expect(AppBreakpoints.fromWidth(1200), WindowSize.expanded);
  });

  test('only expanded shows the navigation rail', () {
    expect(WindowSize.compact.showsRail, isFalse);
    expect(WindowSize.medium.showsRail, isFalse);
    expect(WindowSize.expanded.showsRail, isTrue);
  });
}
