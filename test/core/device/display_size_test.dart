import 'package:finroot_mobile/app/display_scale.dart';
import 'package:finroot_mobile/core/device/device_prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _shared(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('DisplaySize.clamp', () {
    test('keeps values on whole steps inside the range', () {
      expect(DisplaySize.clamp(87), 85);
      expect(DisplaySize.clamp(10), DisplaySize.min);
      expect(DisplaySize.clamp(400), DisplaySize.max);
      expect(DisplaySize.clamp(double.nan), DisplaySize.standard);
    });
  });

  group('DevicePrefs.displaySize', () {
    test('nothing stored is 100 %', () async {
      final p = DevicePrefs(await _shared({}));
      expect(p.displaySize, DisplaySize.standard);
    });

    test('round-trips, and a stored out-of-range value is clamped', () async {
      final shared = await _shared({'finroot.display_size': 300});
      final p = DevicePrefs(shared);
      expect(p.displaySize, DisplaySize.max);
      await p.setDisplaySize(85);
      expect(p.displaySize, 85);
    });

    test('back to the default removes the key', () async {
      final shared = await _shared({});
      final p = DevicePrefs(shared);
      await p.setDisplaySize(110);
      await p.setDisplaySize(DisplaySize.standard);
      expect(shared.containsKey('finroot.display_size'), isFalse);
    });
  });

  test('the provider applies a new size and saves it', () async {
    final shared = await _shared({});
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(shared)],
    );
    addTearDown(container.dispose);
    expect(container.read(displaySizeProvider), 100);
    await container.read(displaySizeProvider.notifier).set(90);
    expect(container.read(displaySizeProvider), 90);
    expect(shared.getInt('finroot.display_size'), 90);
  });

  group('DisplayScale', () {
    Future<(Size, Size)> layoutAt(WidgetTester tester, double scale) async {
      late Size seen;
      final box = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DisplayScale(
              scale: scale,
              child: Builder(
                builder: (context) {
                  seen = MediaQuery.sizeOf(context);
                  return SizedBox.expand(key: box);
                },
              ),
            ),
          ),
        ),
      );
      final drawn = tester.getSize(find.byKey(box));
      return (seen, drawn);
    }

    testWidgets('smaller: the app lays out on a larger screen', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (seen, drawn) = await layoutAt(tester, 0.8);
      expect(seen, const Size(500, 1000));
      expect(drawn, const Size(500, 1000));
    });

    testWidgets('larger: less room, and taps still land', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var taps = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: DisplayScale(
              scale: 1.25,
              child: Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  // An empty SizedBox is not hit-testable on its own.
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
            ),
          ),
        ),
      );
      // The 40 x 40 box sits at the bottom-right of a 320 x 640 layout, which
      // is drawn 1.25 x larger: on screen it is 50 x 50 in the real corner.
      final rect = tester.getRect(find.byType(GestureDetector));
      expect(rect.size.width, closeTo(50, 0.01));
      expect(rect.bottomRight.dx, closeTo(400, 0.01));
      expect(rect.bottomRight.dy, closeTo(800, 0.01));
      await tester.tapAt(const Offset(390, 790));
      expect(taps, 1);
    });

    testWidgets('changing the size keeps the app state (no rebuild from scratch)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget app(double scale) => MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DisplayScale(scale: scale, child: const _Counter()),
        ),
      );
      await tester.pumpWidget(app(1.0));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(app(0.9));
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(app(1.0));
      expect(find.text('1'), findsOneWidget);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => n++),
    child: Text('$n'),
  );
}
