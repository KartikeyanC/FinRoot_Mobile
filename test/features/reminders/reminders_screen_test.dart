import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:finroot_mobile/features/reminders/presentation/reminders_screen.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Reminder _r(String title, int daysOut) => Reminder(
  id: title,
  title: title,
  context: ReminderContext.fixedDue,
  dueDate: DateTime.now().add(Duration(days: daysOut)),
  status: 'scheduled',
);

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<Reminder> reminders = const [],
  WorkspaceRole role = WorkspaceRole.owner,
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(role),
      menuStatusProvider(FeatureMenu.reminders).overrideWithValue(menu),
      remindersProvider.overrideWith((ref) async => reminders),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const RemindersScreen()),
  );
}

void main() {
  testWidgets('locked menu shows the paywall', (tester) async {
    await tester.pumpWidget(_host(menu: MenuStatus.locked));
    await tester.pump();
    expect(find.textContaining('isn\'t available'), findsOneWidget);
  });

  testWidgets('empty state offers to add', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('No reminders yet'), findsOneWidget);
  });

  testWidgets('lists reminders with a Done action', (tester) async {
    await tester.pumpWidget(_host(reminders: [_r('HDFC card bill', 4)]));
    await tester.pumpAndSettle();
    expect(find.text('HDFC card bill'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.textContaining('Due in 4d'), findsOneWidget);
  });
}
