import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/quick_add/presentation/floating_quick_add_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQuickAdd extends QuickAddController {
  _FakeQuickAdd(super.ref, {this.fail});
  final Failure? fail;
  final calls = <({QuickAddKind kind, Money amount, String? category, String? note})>[];

  @override
  Future<String> submit({
    required QuickAddKind kind,
    required Money amount,
    required DateTime occurredAt,
    String? category,
    String? note,
    String? paymentMode,
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? editingId,
  }) async {
    if (fail != null) throw fail!;
    calls.add((kind: kind, amount: amount, category: category, note: note));
    return 'txn-1';
  }
}

Future<({_FakeQuickAdd quickAdd, List<int> closed})> _pump(
  WidgetTester tester, {
  Failure? fail,
}) async {
  late _FakeQuickAdd fake;
  final closed = <int>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quickAddControllerProvider.overrideWith((ref) => fake = _FakeQuickAdd(ref, fail: fail)),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: FloatingQuickAddScreen(close: () => closed.add(1)),
      ),
    ),
  );
  await tester.pump();
  // Touch the provider so `fake` exists even before the first save.
  final container = ProviderScope.containerOf(tester.element(find.byType(FloatingQuickAddScreen)));
  container.read(quickAddControllerProvider);
  return (quickAdd: fake, closed: closed);
}

void main() {
  test('amounts are checked before anything is saved', () {
    expect(amountProblem(''), isNotNull);
    expect(amountProblem('0'), isNotNull);
    expect(amountProblem('abc'), isNotNull);
    expect(amountProblem('249.50'), isNull);
  });

  test('the six quick categories save as FinRoot categories', () {
    expect(quickCategories.map((c) => c.label), [
      'Food', 'Travel', 'Groceries', 'Shopping', 'Bills', 'Others',
    ]);
    expect(quickCategories.map((c) => c.category), [
      'Food & Dining', 'Travel', 'Food & Dining', 'Shopping', 'Utilities', 'Other',
    ]);
    expect(quickCategories[2].note, 'Groceries');
  });

  testWidgets('the amount is focused, and Save adds the expense and closes', (tester) async {
    final h = await _pump(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofocus, isTrue);
    expect(field.keyboardType, const TextInputType.numberWithOptions(decimal: true));
    expect(find.byType(ChoiceChip), findsNWidgets(6));

    await tester.enterText(find.byType(TextField), '249.50');
    await tester.tap(find.text('Bills'));
    await tester.pump();
    await tester.tap(find.text('Save expense'));
    await tester.pump();

    expect(h.quickAdd.calls.single.kind, QuickAddKind.expense);
    expect(h.quickAdd.calls.single.amount.toStorageString(), '249.50');
    expect(h.quickAdd.calls.single.category, 'Utilities');
    expect(h.closed, [1], reason: 'the window closes as soon as it is saved');
  });

  testWidgets('Groceries saves under Food & Dining with a note', (tester) async {
    final h = await _pump(tester);
    await tester.enterText(find.byType(TextField), '600');
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.tap(find.text('Save expense'));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Food & Dining');
    expect(h.quickAdd.calls.single.note, 'Groceries');
  });

  testWidgets('no amount: says so and stays open', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Save expense'));
    await tester.pump();
    expect(find.text('Enter the amount you paid.'), findsOneWidget);
    expect(h.quickAdd.calls, isEmpty);
    expect(h.closed, isEmpty);
  });

  testWidgets('a failed save shows why and keeps the window open', (tester) async {
    final h = await _pump(
      tester,
      fail: const PermissionFailure(message: 'Only owners and admins can add.'),
    );
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.text('Save expense'));
    await tester.pump();
    expect(find.text('Only owners and admins can add.'), findsOneWidget);
    expect(h.closed, isEmpty);
  });

  testWidgets('tapping outside the card cancels', (tester) async {
    final h = await _pump(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(h.closed, [1]);
  });
}
