import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/data/custom_categories.dart';
import 'package:finroot_mobile/features/quick_add/data/custom_subcategories.dart';
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

/// Custom categories without Supabase: [add] keeps them in memory.
class _FakeCustom extends CustomExpenseCategories {
  _FakeCustom(this.initial);
  final List<String> initial;

  @override
  Future<List<String>> build() async => initial;

  @override
  Future<String> add(String name) async {
    final problem = customCategoryProblem(name, state.value ?? const []);
    if (problem != null) throw ValidationFailure(problem);
    state = AsyncData([...?state.value, name.trim()]);
    return name.trim();
  }
}

/// Custom subcategories without Supabase.
class _FakeSubs extends CustomSubcategories {
  @override
  Future<Map<String, List<String>>> build() async => const {};

  @override
  Future<String> add(String group, String name) async {
    final current = state.value ?? const <String, List<String>>{};
    state = AsyncData({
      ...current,
      group: [...?current[group], name.trim()],
    });
    return name.trim();
  }
}

Future<({_FakeQuickAdd quickAdd, List<int> closed, List<String> events})> _pump(
  WidgetTester tester, {
  Failure? fail,
  List<String> custom = const [],
}) async {
  late _FakeQuickAdd fake;
  final closed = <int>[];
  final events = <String>[];
  // A typical phone (1080×2340), so the whole card is on screen.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quickAddControllerProvider.overrideWith((ref) => fake = _FakeQuickAdd(ref, fail: fail)),
        customExpenseCategoriesProvider.overrideWith(() => _FakeCustom(custom)),
        customSubcategoriesProvider.overrideWith(_FakeSubs.new),
        quickLogAfterSaveProvider.overrideWithValue(() async => events.add('pushed')),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: FloatingQuickAddScreen(close: () {
          closed.add(1);
          events.add('closed');
        }),
      ),
    ),
  );
  await tester.pump();
  // Touch the provider so `fake` exists even before the first save.
  final container = ProviderScope.containerOf(tester.element(find.byType(FloatingQuickAddScreen)));
  container.read(quickAddControllerProvider);
  return (quickAdd: fake, closed: closed, events: events);
}

/// Types [digits] on the card's numpad.
Future<void> _type(WidgetTester tester, String digits) async {
  for (final k in digits.split('')) {
    await tester.tap(find.widgetWithText(TextButton, k));
  }
  await tester.pump();
}

/// Scrolls the subcategory row until [label] is on screen (it builds lazily).
Future<void> _showChip(WidgetTester tester, Finder chip) async {
  await tester.scrollUntilVisible(
    chip,
    120,
    scrollable: find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.right,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('amounts are checked before anything is saved', () {
    expect(amountProblem(''), isNotNull);
    expect(amountProblem('0'), isNotNull);
    expect(amountProblem('abc'), isNotNull);
    expect(amountProblem('249.50'), isNull);
  });

  test('the numpad keeps a well-formed amount', () {
    String typed(List<String> keys) => keys.fold('', pressKey);
    expect(typed(['2', '4', '9', '.', '5', '0']), '249.50');
    expect(typed(['.', '5']), '0.5');
    expect(typed(['1', '.', '2', '3', '4']), '1.23', reason: 'two decimals at most');
    expect(typed(['1', '.', '.', '2']), '1.2', reason: 'one decimal point');
    expect(typed(['0', '0', '7']), '7', reason: 'no leading zeros');
    expect(typed(List.filled(12, '9')), '999999999', reason: 'nine whole digits');
    expect(typed(['4', '2', backspaceKey]), '4');
    expect(typed([backspaceKey]), '');
    expect(amountPreview(''), '₹ 0.00');
    expect(amountPreview('249.5'), '₹ 249.5');
  });

  test('the six quick categories save as FinRoot categories', () {
    expect(quickCategories.map((c) => c.label), [
      'Food', 'Travel', 'Grocery', 'Shopping', 'Bills', 'Entertainment',
    ]);
    expect(quickCategories.map((c) => c.category), [
      'Food & Dining', 'Travel', 'Food & Dining', 'Shopping', 'Utilities', 'Entertainment',
    ]);
    expect(quickCategories[2].note, 'Groceries');
  });

  testWidgets('no text field, so the system keyboard never opens', (tester) async {
    await _pump(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('₹ 0.00'), findsOneWidget);
    for (final c in quickCategories) {
      expect(find.text(c.label), findsOneWidget);
    }
    expect(find.text('New'), findsOneWidget, reason: 'the add-category tile');
  });

  testWidgets('numpad + pill + Save adds the expense and closes', (tester) async {
    final h = await _pump(tester);
    await _type(tester, '249.50');
    expect(find.text('₹ 249.50'), findsOneWidget);

    await tester.tap(find.text('Bills'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();

    expect(h.quickAdd.calls.single.kind, QuickAddKind.expense);
    expect(h.quickAdd.calls.single.amount.toStorageString(), '249.50');
    expect(h.quickAdd.calls.single.category, 'Utilities');
    expect(h.closed, [1], reason: 'the window closes once it is saved');
    expect(h.events, ['pushed', 'closed'], reason: 'the push finishes before the window closes');
  });

  testWidgets('Grocery saves under Food & Dining with a note', (tester) async {
    final h = await _pump(tester);
    await _type(tester, '600');
    await tester.tap(find.text('Grocery'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Food & Dining');
    expect(h.quickAdd.calls.single.note, 'Groceries');
  });

  testWidgets('a picked subcategory saves as "Sub · note"', (tester) async {
    final h = await _pump(tester);
    expect(find.text('Subcategory · optional'), findsNothing, reason: 'nothing until a pill is picked');
    await _type(tester, '600');
    await tester.tap(find.text('Grocery'));
    await tester.pump();
    await _showChip(tester, find.text('Snacks'));
    await tester.tap(find.text('Snacks'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Food & Dining');
    expect(h.quickAdd.calls.single.note, 'Snacks · Groceries');
  });

  testWidgets('the summary says where the save will go before Save is tapped', (tester) async {
    await _pump(tester);
    expect(find.text('No category · saves as Other'), findsOneWidget);
    await tester.tap(find.text('Grocery'));
    await tester.pump();
    await _showChip(tester, find.text('Snacks'));
    await tester.tap(find.text('Snacks'));
    await tester.pump();
    expect(find.text('Grocery › Snacks'), findsOneWidget);
    await _type(tester, '45');
    expect(find.text('Save ₹ 45'), findsOneWidget, reason: 'the button names the amount');
  });

  testWidgets('New under a category adds a subcategory and picks it', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Food'));
    await tester.pump();
    await _showChip(tester, find.widgetWithText(ActionChip, 'New'));
    await tester.tap(find.widgetWithText(ActionChip, 'New'));
    await tester.pumpAndSettle();
    expect(find.text('New subcategory in Food & Dining'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Tea');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Food › Tea'), findsOneWidget);
    await _type(tester, '20');
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Food & Dining');
    expect(h.quickAdd.calls.single.note, 'Tea');
  });

  testWidgets('no pill picked saves as Other', (tester) async {
    final h = await _pump(tester);
    await _type(tester, '80');
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Other');
    expect(h.quickAdd.calls.single.note, isNull);
  });

  test('custom categories read and extend the web tenant_settings shape', () {
    expect(parseCustomExpense(null), isEmpty);
    expect(parseCustomExpense({'expense': ['Petrol', ' ', 3]}), ['Petrol']);
    final next = withCustomExpense({
      'income': {'active': ['Tips'], 'passive': <String>[]},
      'expense': ['Petrol'],
    }, 'Pets');
    expect(next['expense'], ['Petrol', 'Pets']);
    expect((next['income'] as Map)['active'], ['Tips'], reason: 'income lists are kept');
    expect(withCustomExpense(null, 'Pets')['expense'], ['Pets']);
    expect(customCategoryProblem(' ', const []), isNotNull);
    expect(customCategoryProblem('shopping', const []), isNotNull, reason: 'built-in');
    expect(customCategoryProblem('petrol', const ['Petrol']), isNotNull, reason: 'custom');
    expect(customCategoryProblem('Gifts', const ['Petrol']), isNull);
  });

  testWidgets('a workspace category saves under its own name', (tester) async {
    final h = await _pump(tester, custom: ['Petrol']);
    await _type(tester, '500');
    await tester.tap(find.text('Petrol'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Petrol');
    expect(h.quickAdd.calls.single.note, isNull);
  });

  testWidgets('Add category names one, picks it and saves with it', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Shopping');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();
    expect(find.text('"Shopping" is already a category.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Pets');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(find.text('Pets'), findsWidgets);

    await _type(tester, '350');
    await tester.tap(find.byKey(const Key('quick-log-save')));
    await tester.pump();
    expect(h.quickAdd.calls.single.category, 'Pets');
  });

  testWidgets('long-press backspace clears the amount', (tester) async {
    await _pump(tester);
    await _type(tester, '123');
    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('₹ 0.00'), findsOneWidget);
  });

  testWidgets('no amount: says so and stays open', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const Key('quick-log-save')));
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
    await _type(tester, '100');
    await tester.tap(find.byKey(const Key('quick-log-save')));
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
