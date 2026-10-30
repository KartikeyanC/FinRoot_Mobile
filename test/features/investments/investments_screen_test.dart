import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/domain/constants.dart';
import 'package:finroot_mobile/features/investments/application/investments_providers.dart';
import 'package:finroot_mobile/features/investments/domain/investment.dart';
import 'package:finroot_mobile/features/investments/presentation/investments_screen.dart';
import 'package:finroot_mobile/features/menus/application/menu_providers.dart';
import 'package:finroot_mobile/features/workspace/application/workspace_providers.dart';
import 'package:finroot_mobile/features/workspace/domain/membership.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

InvestmentRecord _rec(String name, String invested, String current) =>
    InvestmentRecord(
      id: name,
      asset: 'stocks',
      currency: 'INR',
      fields: {
        'name': name,
        'invested': invested,
        'current': current,
        '_mobile': '1',
      },
      derived: const {},
    );

Widget _host({
  MenuStatus menu = MenuStatus.available,
  List<InvestmentRecord> records = const [],
}) {
  return ProviderScope(
    overrides: [
      currentRoleProvider.overrideWithValue(WorkspaceRole.owner),
      menuStatusProvider(FeatureMenu.investments).overrideWithValue(menu),
      investmentsProvider.overrideWith((ref) async => records),
    ],
    child: MaterialApp(theme: AppTheme.light, home: const InvestmentsScreen()),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.text('No holdings yet'), findsOneWidget);
  });

  testWidgets('lists holdings with a portfolio summary', (tester) async {
    await tester.pumpWidget(
      _host(
        records: [
          _rec('ITC', '10000', '13000'),
          _rec('Gold ETF', '20000', '19000'),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('ITC'), findsOneWidget);
    expect(find.text('CURRENT VALUE'), findsOneWidget);
    // total gain 3000 - 1000 = +2000 → "+₹2.0k (6.7%)"
    expect(find.textContaining('6.7%'), findsOneWidget);
  });
}
