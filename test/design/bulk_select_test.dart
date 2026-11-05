import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BulkSelection', () {
    test('long-press starts, toggling the last row off ends it', () {
      final s = BulkSelection();
      expect(s.active, isFalse);
      s.start('a');
      expect(s.active, isTrue);
      expect(s.ids, {'a'});
      s.toggle('b');
      expect(s.count, 2);
      s
        ..toggle('a')
        ..toggle('b');
      expect(s.active, isFalse);
      expect(s.count, 0);
    });

    test('select all ticks what is shown, and pressed again unticks it', () {
      final s = BulkSelection()..start('a');
      s.toggleAll(['a', 'b', 'c']);
      expect(s.ids, {'a', 'b', 'c'});
      s.toggleAll(['a', 'b', 'c']);
      expect(s.count, 0);
      expect(s.active, isTrue, reason: 'still selecting until closed');
      s.clear();
      expect(s.active, isFalse);
    });
  });

  Widget host(Widget Function(BuildContext) body) => MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Builder(builder: body)),
  );

  testWidgets('deleteSelected confirms once, deletes each, and reports', (
    tester,
  ) async {
    final s = BulkSelection()
      ..start('a')
      ..toggle('b');
    final deleted = <String>[];
    late BuildContext ctx;
    await tester.pumpWidget(
      host((c) {
        ctx = c;
        return const SizedBox();
      }),
    );

    final run = deleteSelected(
      ctx,
      selection: s,
      one: 'goal',
      many: 'goals',
      delete: (id) async => deleted.add(id),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete 2 goals?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await run, 2);
    expect(deleted, unorderedEquals(['a', 'b']));
    expect(s.active, isFalse);
    expect(find.text('Deleted 2 goals'), findsOneWidget);
  });

  testWidgets('cancel deletes nothing and keeps the ticks', (tester) async {
    final s = BulkSelection()..start('a');
    var calls = 0;
    late BuildContext ctx;
    await tester.pumpWidget(
      host((c) {
        ctx = c;
        return const SizedBox();
      }),
    );

    final run = deleteSelected(
      ctx,
      selection: s,
      one: 'goal',
      many: 'goals',
      delete: (_) async => calls++,
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete 1 goal?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await run, 0);
    expect(calls, 0);
    expect(s.ids, {'a'});
  });

  testWidgets('a failed delete stays ticked and says why', (tester) async {
    final s = BulkSelection()
      ..start('ok')
      ..toggle('bad');
    late BuildContext ctx;
    await tester.pumpWidget(
      host((c) {
        ctx = c;
        return const SizedBox();
      }),
    );

    final run = deleteSelected(
      ctx,
      selection: s,
      one: 'reminder',
      many: 'reminders',
      delete: (id) async {
        if (id == 'bad') throw const PermissionFailure();
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(await run, 1);
    expect(s.ids, {'bad'});
    expect(find.textContaining('Deleted 1 of 2.'), findsOneWidget);
  });

  testWidgets('SelectableTile: long-press starts, taps toggle, the card '
      'underneath does not react while selecting', (tester) async {
    final s = BulkSelection();
    var cardTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: s,
            builder: (context, _) => SelectableTile(
              selecting: s.active,
              selected: s.contains('a'),
              onToggle: () => s.toggle('a'),
              onLongPress: () => s.start('a'),
              child: ListTile(
                title: const Text('Rent'),
                onTap: () => cardTaps++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rent'));
    expect(cardTaps, 1, reason: 'a normal tap still opens the card');

    await tester.longPress(find.text('Rent'));
    await tester.pump();
    expect(s.ids, {'a'});
    expect(find.byType(SelectCheck), findsOneWidget);

    await tester.tap(find.text('Rent'));
    await tester.pump();
    expect(s.active, isFalse);
    expect(cardTaps, 1);
  });
}
