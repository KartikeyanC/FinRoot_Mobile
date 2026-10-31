import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/quick_add/application/quick_add_controller.dart';
import 'package:finroot_mobile/features/quick_add/data/custom_categories.dart';
import 'package:finroot_mobile/features/quick_add/data/custom_subcategories.dart';
import 'package:finroot_mobile/features/quick_add/domain/expense_subcategories.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeQuickAdd extends QuickAddController {
  _FakeQuickAdd(super.ref);
  final calls = <({String? category, String? note})>[];

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
    calls.add((category: category, note: note));
    return 'txn-1';
  }
}

class _FakeSubs extends CustomSubcategories {
  _FakeSubs(this.initial);
  final Map<String, List<String>> initial;

  @override
  Future<Map<String, List<String>>> build() async => initial;

  @override
  Future<String> add(String group, String name) async {
    final problem = customSubcategoryProblem(name, group, state.value ?? {});
    if (problem != null) throw ValidationFailure(problem);
    state = AsyncData({
      ...?state.value,
      group: [...?state.value?[group], name.trim()],
    });
    return name.trim();
  }
}

class _NoCats extends CustomExpenseCategories {
  @override
  Future<List<String>> build() async => const [];
}

void main() {
  group('description compose / split', () {
    test('compose: Sub · note, or just the half that exists', () {
      expect(composeDescription('Swiggy', 'biryani'), 'Swiggy · biryani');
      expect(composeDescription('Swiggy', '  '), 'Swiggy');
      expect(composeDescription(null, ' lunch '), 'lunch');
      expect(composeDescription(null, ''), '');
    });

    test('round-trips, including a note that has " · " in it', () {
      const known = ['Swiggy', 'Snacks'];
      for (final (sub, note) in [
        ('Swiggy', 'biryani'),
        ('Swiggy', 'a · b · c'),
        ('Snacks', ''),
        (null, 'plain note'),
      ]) {
        final back = splitDescription(composeDescription(sub, note), known);
        expect((back.sub, back.note), (sub, note));
      }
    });

    test('a prefix that is not a known sub stays in the note', () {
      final r = splitDescription('Dinner · with Raj', ['Swiggy']);
      expect(r.sub, isNull);
      expect(r.note, 'Dinner · with Raj');
      expect(splitDescription(null, ['Swiggy']), (sub: null, note: ''));
    });
  });

  group('groups', () {
    test('mobile categories map to the web group names', () {
      expect(groupNameForCategory('Food & Dining'), 'Food & Dining');
      expect(groupNameForCategory('Transport'), 'Travel & Transport');
      expect(groupNameForCategory('Travel'), 'Travel & Transport');
      expect(groupNameForCategory('Shopping'), 'Shopping & Personal');
      expect(groupNameForCategory('Personal Care'), 'Shopping & Personal');
      expect(groupNameForCategory('Healthcare'), 'Healthcare & Wellness');
      expect(groupNameForCategory('Education'), 'Education & Development');
      expect(groupNameForCategory('Entertainment'), 'Entertainment & Leisure');
      expect(groupNameForCategory('Utilities'), 'Housing & Utilities');
      expect(groupNameForCategory('Rent'), 'Housing & Utilities');
      expect(groupNameForCategory('Subscriptions'), 'Subscriptions & Memberships');
      expect(groupNameForCategory('Other'), isNull);
      expect(groupNameForCategory('Pets'), 'Pets');
      expect(builtInSubsFor('Pets'), isEmpty);
      expect(builtInSubsFor('Transport'), contains('Fuel'));
    });

    test('findGroupForSub', () {
      expect(findGroupForSub('Snacks')?.name, 'Food & Dining');
      expect(findGroupForSub('Swiggy'), isNull);
    });

    test('custom subs merge under category and group name, de-duplicated', () {
      final store = {
        'Transport': ['Parking', 'Fuel'],
        'Travel & Transport': ['parking', 'Metro'],
      };
      final opts = subOptionsFor('Transport', store);
      expect(opts.take(3), ['Parking', 'Fuel', 'Metro']);
      expect(opts.where((s) => s.toLowerCase() == 'fuel'), hasLength(1));
      expect(opts.where((s) => s.toLowerCase() == 'parking'), hasLength(1));
      expect(opts, contains('Hill Stations'));
    });

    test('custom subs come before built-ins; Other has none', () {
      final opts = subOptionsFor('Food & Dining', {
        'Food & Dining': ['Hotel', 'Swiggy', 'Zomato'],
      });
      expect(opts.take(3), ['Hotel', 'Swiggy', 'Zomato']);
      expect(opts, contains('Outside Food'));
      expect(subOptionsFor('Other', {'Other': ['x']}), isEmpty);
    });

    test('a custom head category lists its own custom subs', () {
      expect(subOptionsFor('Pets', {'Pets': ['Vet']}), ['Vet']);
    });
  });

  group('parseCustomSubcategories', () {
    test('reads the web shape', () {
      expect(
        parseCustomSubcategories({
          'Food & Dining': ['Hotel', ' Swiggy '],
        }),
        {'Food & Dining': ['Hotel', 'Swiggy']},
      );
    });

    test('malformed values read as none', () {
      expect(parseCustomSubcategories(null), isEmpty);
      expect(parseCustomSubcategories('not json {'), isEmpty);
      expect(parseCustomSubcategories([1, 2]), isEmpty);
      expect(
        parseCustomSubcategories({
          'A': 'oops',
          'B': [1, null, '', 'ok'],
          3: ['x'],
        }),
        {'B': ['ok']},
      );
      expect(parseCustomSubcategories('{"A":["x"]}'), {'A': ['x']});
    });

    test('add validation', () {
      const g = 'Food & Dining';
      expect(customSubcategoryProblem(' ', g, {}), isNotNull);
      expect(customSubcategoryProblem('x' * 41, g, {}), isNotNull);
      expect(customSubcategoryProblem('snacks', g, {}), isNotNull);
      expect(
        customSubcategoryProblem('SWIGGY', g, {g: ['Swiggy']}),
        isNotNull,
      );
      expect(customSubcategoryProblem('Zomato', g, {}), isNull);
    });
  });

  group('Quick Add sheet', () {
    testWidgets('shows custom subs first and saves "Sub · note"', (tester) async {
      late _FakeQuickAdd fake;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
            currentTenantIdProvider.overrideWithValue('t1'),
            currentUserIdProvider.overrideWithValue('u1'),
            customExpenseCategoriesProvider.overrideWith(_NoCats.new),
            customSubcategoriesProvider.overrideWith(
              () => _FakeSubs({
                'Food & Dining': ['Hotel', 'Swiggy', 'Zomato'],
              }),
            ),
            quickAddControllerProvider.overrideWith(
              (ref) => fake = _FakeQuickAdd(ref),
            ),
            workspaceAccountsProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: QuickAddSheet()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      // No category yet: no subcategory chips.
      expect(find.text('Subcategory (optional)'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '250');
      await tester.tap(find.text('Food & Dining'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Subcategory (optional)'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Swiggy'), findsOneWidget);
      expect(find.text('Outside Food'), findsOneWidget);
      // The person's own subs sit before the built-ins.
      expect(
        tester.getTopLeft(find.text('Hotel')).dy <=
            tester.getTopLeft(find.text('Outside Food')).dy,
        isTrue,
      );

      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Swiggy'));
      await tester.tap(find.text('Swiggy'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'biryani');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.category, 'Food & Dining');
      expect(fake.calls.single.note, 'Swiggy · biryani');
    });
  });
}
