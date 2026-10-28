import 'package:finroot_mobile/core/providers/providers.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/accounts/application/accounts_providers.dart';
import 'package:finroot_mobile/features/accounts/domain/account.dart';
import 'package:finroot_mobile/features/quick_add/domain/quick_add_draft.dart';
import 'package:finroot_mobile/features/quick_add/presentation/quick_add_sheet.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AccountEntity _acc(String id, String name) =>
    AccountEntity(id: id, name: name, type: 'bank');

Widget _host({
  WorkspaceRole role = WorkspaceRole.owner,
  List<AccountEntity> accounts = const [],
  QuickAddKind kind = QuickAddKind.expense,
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(role),
      currentTenantIdProvider.overrideWithValue('t1'),
      currentUserIdProvider.overrideWithValue('u1'),
      workspaceAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: QuickAddSheet(initialKind: kind)),
    ),
  );
}

void main() {
  testWidgets('offers the three capture kinds and a save button', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('on a 360dp phone labels fit one line and ₹ hugs the amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host());
    await tester.pump();

    // A wrapped label ("Transfe / r") would be two lines tall.
    final lineHeight = tester.getSize(find.text('Income')).height;
    for (final label in ['Expense', 'Transfer']) {
      expect(tester.getSize(find.text(label)).height, lineHeight);
    }

    // The symbol sits beside the figure, and the pair is centred.
    final symbol = tester.getRect(find.text('₹'));
    final field = tester.getRect(find.byType(TextField).first);
    expect(field.left - symbol.right, lessThanOrEqualTo(AppSpacing.sm + 1));
    expect((symbol.left + field.right) / 2, closeTo(180, 2));

    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets('an empty amount fails validation and nothing is submitted', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text('Enter an amount'), findsOneWidget);
  });

  testWidgets('a view-only role sees an explanation, no form', (tester) async {
    await tester.pumpWidget(_host(role: WorkspaceRole.viewer));
    await tester.pump();

    expect(find.textContaining('view-only'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(SegmentedButton<QuickAddKind>), findsNothing);
  });

  testWidgets('transfer with fewer than two accounts explains why', (
    tester,
  ) async {
    await tester.pumpWidget(_host(kind: QuickAddKind.transfer));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('transfer moves money'), findsOneWidget);
    expect(find.text('From'), findsNothing);
  });

  testWidgets('transfer with two accounts shows From / To pickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        kind: QuickAddKind.transfer,
        accounts: [_acc('a', 'SBI'), _acc('b', 'Cash')],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('From'), findsOneWidget);
    expect(find.text('To'), findsOneWidget);
  });
}
