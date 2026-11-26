import 'package:decimal/decimal.dart';
import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/goals/application/goal_editor_controller.dart';
import 'package:finroot_mobile/features/goals/application/goals_providers.dart';
import 'package:finroot_mobile/features/goals/domain/goal.dart';
import 'package:finroot_mobile/features/goals/domain/goal_draft.dart';
import 'package:finroot_mobile/features/goals/domain/goal_history.dart';
import 'package:finroot_mobile/features/goals/presentation/goal_history_sheet.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _goal = GoalEntity(
  id: 'g1',
  title: 'Trip',
  target: Money.parse('10000'),
  current: Money.parse('400'),
);

/// Records history edits instead of calling the server.
class _RecordingEditor extends GoalEditorController {
  _RecordingEditor(super.ref);
  final edits = <(String, String, double, String?, DateTime?)>[];
  final deletes = <(String, String)>[];

  @override
  Future<GoalContribution> editContribution(
    String goalId,
    String entryId,
    double amount, {
    String? note,
    DateTime? date,
  }) async {
    edits.add((goalId, entryId, amount, note, date));
    return GoalContribution.fromRpc({'current_amount': 0, 'status': 'active'});
  }

  @override
  Future<GoalContribution> deleteContribution(
    String goalId,
    String entryId,
  ) async {
    deletes.add((goalId, entryId));
    return GoalContribution.fromRpc({'current_amount': 0, 'status': 'active'});
  }
}

_RecordingEditor? _editor;

Widget _host(
  GoalHistory history, {
  WorkspaceRole role = WorkspaceRole.owner,
  GoalEntity? goal,
}) => ProviderScope(
  overrides: [
    goalHistoryProvider.overrideWith((ref, key) async => history),
    goalByIdProvider.overrideWith((ref, id) => Stream.value(goal ?? _goal)),
    currentRoleProvider.overrideWithValue(role),
    isOnlineProvider.overrideWithValue(true),
    goalEditorControllerProvider.overrideWith(
      (ref) => _editor = _RecordingEditor(ref),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: GoalHistoryList(goal: goal ?? _goal)),
  ),
);

GoalHistory _one(String amount, {String? note}) => GoalHistory([
  GoalContributionEntry.fromRow({
    'id': 'c1',
    'goal_id': 'g1',
    'amount': amount,
    'note': ?note,
    'contributed_at': '2026-11-02T10:00:00Z',
  }),
]);

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

  group('editing an entry', () {
    setUp(() => _editor = null);

    test('the server rules, checked before sending', () {
      // Goal holds 900 of 1000.
      String? p(double original, double next, {bool deleting = false}) =>
          historyChangeProblem(
            original: original,
            next: next,
            deleting: deleting,
            currentAmount: 900,
            targetAmount: 1000,
          );
      expect(p(500, 300), isNull);
      expect(p(500, 600), isNull);
      expect(p(500, 0, deleting: true), isNull);
      expect(p(500, 700), contains('past its target of 1000'));
      expect(p(-200, 0, deleting: true), contains('past its target'));
      expect(p(500, 0), contains('delete it'));
      expect(
        historyChangeProblem(
          original: 500,
          next: 0,
          deleting: true,
          currentAmount: 300,
          targetAmount: 1000,
        ),
        contains('below zero'),
      );
      expect(
        historyChangeProblem(
          original: 500,
          next: 400,
          currentAmount: 900,
          targetAmount: 1000,
          date: DateTime(2026, 12, 2),
          today: DateTime(2026, 11, 26),
        ),
        "The date can't be in the future",
      );
    });

    test('knows when the edit functions are not switched on yet', () {
      expect(isGoalHistoryEditMissingError('PGRST202', null), isTrue);
      expect(
        isGoalHistoryEditMissingError(
          null,
          'function public.goal_contribution_update does not exist',
        ),
        isTrue,
      );
      expect(
        isGoalHistoryEditMissingError('22023', 'past its target'),
        isFalse,
      );
    });

    testWidgets('tap an entry, change it, save', (tester) async {
      await tester.pumpWidget(_host(_one('500', note: 'bonus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-history-c1')));
      await tester.pumpAndSettle();
      expect(find.text('Edit history entry'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('goal-history-amount')),
        '300',
      );
      await tester.enterText(
        find.byKey(const Key('goal-history-note')),
        'half of it',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final (goalId, entryId, amount, note, date) = _editor!.edits.single;
      expect(
        (goalId, entryId, amount, note),
        ('g1', 'c1', 300.0, 'half of it'),
      );
      expect(date, DateTime(2026, 11, 2));
      expect(find.text('History updated'), findsOneWidget);
    });

    testWidgets('an edit past the target is refused before sending', (
      tester,
    ) async {
      final nearlyFull = GoalEntity(
        id: 'g1',
        title: 'Trip',
        target: Money.parse('1000'),
        current: Money.parse('900'),
      );
      await tester.pumpWidget(_host(_one('500'), goal: nearlyFull));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-history-c1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('goal-history-amount')),
        '700',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('past its target of 1000'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      // Save never reached the controller.
      expect(_editor?.edits ?? const [], isEmpty);
    });

    testWidgets('delete asks first, then deletes', (tester) async {
      // The goal holds 900, so taking this 500 out leaves 400.
      final goal = GoalEntity(
        id: 'g1',
        title: 'Trip',
        target: Money.parse('1000'),
        current: Money.parse('900'),
      );
      await tester.pumpWidget(_host(_one('500'), goal: goal));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-history-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('goal-history-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('The goal loses'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(_editor!.deletes.single, ('g1', 'c1'));
    });

    testWidgets('a viewer cannot open an entry', (tester) async {
      await tester.pumpWidget(_host(_one('500'), role: WorkspaceRole.viewer));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('goal-history-c1')));
      await tester.pumpAndSettle();
      expect(find.text('Edit history entry'), findsNothing);
      expect(find.text('Tap an entry to change or delete it.'), findsNothing);
    });
  });
}
