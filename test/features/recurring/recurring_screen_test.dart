import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/recurring/domain/reminder_setting.dart';
import 'package:finroot_mobile/features/recurring/presentation/recurring_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringItem _item(String name, RecurringType type, int daysOut) => RecurringItem(
  id: name,
  type: type,
  name: name,
  category: type == RecurringType.income ? 'Salary' : 'Rent',
  amount: Money.parse('25000'),
  frequency: RecurringFrequency.monthly,
  nextDueDate: DateTime.now().add(Duration(days: daysOut)),
  isActive: true,
);

Widget _host({
  List<RecurringItem> items = const [],
  WorkspaceRole role = WorkspaceRole.owner,
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(role),
      recurringItemsProvider.overrideWith((ref) async => items),
      recurringRemindersProvider.overrideWith(
        (ref) async => const <String, ReminderSetting>{},
      ),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const RecurringScreen()),
  );
}

void main() {
  testWidgets('shows Income / Expenses tabs', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
  });

  testWidgets('empty state on the income tab', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('No recurring income'), findsOneWidget);
  });

  testWidgets('lists an expense item with a mark-paid action', (tester) async {
    await tester.pumpWidget(
      _host(items: [_item('Apartment rent', RecurringType.expense, 5)]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.text('Apartment rent'), findsOneWidget);
    expect(find.text('Mark paid'), findsOneWidget);
    expect(find.textContaining('Due in 5d'), findsOneWidget);
  });

  testWidgets('a viewer sees no FAB and no actions', (tester) async {
    await tester.pumpWidget(
      _host(
        items: [_item('Rent', RecurringType.expense, 3)],
        role: WorkspaceRole.viewer,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Mark paid'), findsNothing);
  });
}
