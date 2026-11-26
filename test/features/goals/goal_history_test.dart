import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/goals/domain/goal.dart';
import 'package:finroot_mobile/features/goals/domain/goal_history.dart';
import 'package:finroot_mobile/features/goals/presentation/goal_history_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _goal = GoalEntity(
  id: 'g1',
  title: 'Trip',
  target: Money.parse('10000'),
  current: Money.parse('400'),
);

Widget _host(GoalHistory history) => ProviderScope(
  overrides: [goalHistoryProvider.overrideWith((ref, key) async => history)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: GoalHistoryList(goal: _goal)),
  ),
);

void main() {
  group('rows', () {
    test('maps the web row, numeric strings and blank notes included', () {
      final e = GoalContributionEntry.fromRow({
        'id': 'c1',
        'goal_id': 'g1',
        'amount': '-250.50',
        'note': '  ',
        'contributed_at': '2026-11-26T10:00:00Z',
      });
      expect(e.amount.amount, Decimal.parse('-250.5'));
      expect(e.isWithdrawal, isTrue);
      expect(e.note, isNull);
      expect(e.contributedAt.toUtc(), DateTime.utc(2026, 11, 26, 10));
    });

    test('notes are trimmed and capped, empty is null', () {
      expect(cleanGoalNote('  bonus '), 'bonus');
      expect(cleanGoalNote('   '), isNull);
      expect(cleanGoalNote(null), isNull);
      expect(cleanGoalNote('x' * 300), hasLength(kGoalNoteMax));
    });

    test('a missing table or overload is recognised, other errors are not', () {
      expect(isGoalHistoryMissingError('42P01', null), isTrue);
      expect(isGoalHistoryMissingError('PGRST205', null), isTrue);
      expect(isGoalHistoryMissingError('PGRST202', null), isTrue);
      expect(
        isGoalHistoryMissingError(
          null,
          'relation "public.goal_contributions" does not exist',
        ),
        isTrue,
      );
      expect(isGoalHistoryMissingError('42501', 'permission denied'), isFalse);
    });
  });

  group('list', () {
    testWidgets('shows date, amount and note', (tester) async {
      await tester.pumpWidget(
        _host(
          GoalHistory([
            GoalContributionEntry.fromRow({
              'id': 'c2',
              'goal_id': 'g1',
              'amount': '-100',
              'note': 'Took some back',
              'contributed_at': '2026-11-20T10:00:00Z',
            }),
            GoalContributionEntry.fromRow({
              'id': 'c1',
              'goal_id': 'g1',
              'amount': '500',
              'contributed_at': '2026-11-02T10:00:00Z',
            }),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('20 Nov 2026'), findsOneWidget);
      expect(find.text('2 Nov 2026'), findsOneWidget);
      expect(find.text('Took some back'), findsOneWidget);
      expect(find.textContaining('−'), findsOneWidget);
      expect(find.textContaining('+'), findsOneWidget);
    });

    testWidgets('a missing table shows a hint, not an error', (tester) async {
      await tester.pumpWidget(_host(const GoalHistory.missing()));
      await tester.pumpAndSettle();
      expect(find.text(kGoalHistoryMissingMessage), findsOneWidget);
    });

    testWidgets('an empty history says so', (tester) async {
      await tester.pumpWidget(_host(const GoalHistory([])));
      await tester.pumpAndSettle();
      expect(find.text('No contributions recorded yet.'), findsOneWidget);
    });
  });
}
