import 'package:finroot_mobile/core/widgets/date_time_field.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required DateTime? value,
  required ValueChanged<DateTime> onChanged,
  bool showTime = true,
  DateTime? lastDate,
}) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: DateTimeField(
        value: value,
        onChanged: onChanged,
        showTime: showTime,
        lastDate: lastDate,
      ),
    ),
  ),
);

void main() {
  testWidgets('shows both a Date and a Time field for the value', (t) async {
    await t.pumpWidget(
      _host(value: DateTime(2026, 10, 30, 15, 42), onChanged: (_) {}),
    );
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('30 Oct 2026'), findsOneWidget);
    expect(find.text('3:42 PM'), findsOneWidget);
    expect(find.byKey(const ValueKey('date_time_field.error')), findsNothing);
  });

  testWidgets('a null value shows the required message, no clear control', (
    t,
  ) async {
    await t.pumpWidget(_host(value: null, onChanged: (_) {}));
    expect(find.text('Date and time are required'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('picking a time keeps the date and combines them', (t) async {
    DateTime? result;
    await t.pumpWidget(
      _host(
        value: DateTime(2026, 10, 30, 15, 42),
        onChanged: (v) => result = v,
      ),
    );
    await t.tap(find.byKey(const ValueKey('date_time_field.time')));
    await t.pumpAndSettle();
    // Switch the dialog to keyboard entry and type 9:15.
    await t.tap(find.byIcon(Icons.keyboard_outlined));
    await t.pumpAndSettle();
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), '9');
    await t.enterText(fields.at(1), '15');
    await t.tap(find.text('AM'));
    await t.pump();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(result, DateTime(2026, 10, 30, 9, 15));
  });

  testWidgets('picking a date keeps the time of day', (t) async {
    DateTime? result;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 15, 15, 42);
    await t.pumpWidget(
      _host(value: start, onChanged: (v) => result = v, lastDate: DateTime(now.year + 1)),
    );
    await t.tap(find.byKey(const ValueKey('date_time_field.date')));
    await t.pumpAndSettle();
    await t.tap(find.text('20'));
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(result, DateTime(now.year, now.month, 20, 15, 42));
  });

  testWidgets('date-only mode renders just the Date field', (t) async {
    await t.pumpWidget(
      _host(value: DateTime(2026, 10, 30), showTime: false, onChanged: (_) {}),
    );
    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Time'), findsNothing);
  });

  test('format gives "30 Oct, 3:42 pm"', () {
    expect(
      DateTimeField.format(
        DateTime(2026, 10, 30, 15, 42),
        now: DateTime(2026, 11, 2),
      ),
      '30 Oct, 3:42 pm',
    );
  });
}
