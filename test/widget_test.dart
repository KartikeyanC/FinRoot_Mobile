// M2 smoke test. The full app (`FinRootApp`) needs `Supabase.initialize`, which
// belongs in an integration test — added with the auth work in M3. Here we just
// confirm the design system renders a representative screen.

import 'package:finroot_mobile/design/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a themed screen with core components renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: const [
              SectionHeader('Recent'),
              AppCard(
                child: AmountText(0, size: AmountSize.hero, signed: false),
              ),
              EmptyView(title: 'No transactions yet'),
              PlaceholderScreen(
                title: 'Trackers',
                milestone: 'M9',
                showAppBar: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('No transactions yet'), findsOneWidget);
    expect(find.textContaining('Arrives in M9'), findsOneWidget);
  });
}
