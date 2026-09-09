import 'package:finroot_mobile/core/money/money.dart';
import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/home/presentation/widgets/home_upcoming_card.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/recurring/application/recurring_providers.dart';
import 'package:finroot_mobile/features/recurring/domain/recurring_item.dart';
import 'package:finroot_mobile/features/reminders/application/reminders_providers.dart';
import 'package:finroot_mobile/features/reminders/domain/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RecurringItem _item(String name, int daysOut) => RecurringItem(
  id: name,
  type: RecurringType.expense,
  name: name,
  category: 'Rent',
  amount: Money.parse('25000'),
  frequency: RecurringFrequency.monthly,
  nextDueDate: DateTime.now().add(Duration(days: daysOut)),
  isActive: true,
);

Reminder _rem(String title, int daysOut) => Reminder(
  id: title,
  title: title,
  context: ReminderContext.fixedDue,
  dueDate: DateTime.now().add(Duration(days: daysOut)),
  status: 'scheduled',
);

Widget _host({
  List<RecurringItem> recurring = const [],
  List<Reminder> reminders = const [],
  MenuStatus remindersMenu = MenuStatus.available,
}) => ProviderScope(
  overrides: [
    recurringItemsProvider.overrideWith((ref) async => recurring),
    remindersProvider.overrideWith((ref) async => reminders),
    menuStatusProvider(FeatureMenu.reminders).overrideWithValue(remindersMenu),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: HomeUpcomingCard()),
  ),
);

void main() {
  testWidgets('hides when nothing is upcoming', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsNothing);
  });

  testWidgets('merges recurring + reminders, nearest first', (tester) async {
    await tester.pumpWidget(_host(
      recurring: [_item('Rent', 10)],
      reminders: [_rem('Card bill', 3)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);
    final rentY = tester.getTopLeft(find.text('Rent')).dy;
    final billY = tester.getTopLeft(find.text('Card bill')).dy;
    expect(billY, lessThan(rentY));
  });

  testWidgets('drops items past the 30-day horizon', (tester) async {
    await tester.pumpWidget(_host(recurring: [_item('Far off', 45)]));
    await tester.pumpAndSettle();
    expect(find.text('Far off'), findsNothing);
  });

  testWidgets('omits reminders when that menu is locked', (tester) async {
    await tester.pumpWidget(_host(
      recurring: [_item('Rent', 10)],
      reminders: [_rem('Card bill', 3)],
      remindersMenu: MenuStatus.locked,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Card bill'), findsNothing);
  });
}
