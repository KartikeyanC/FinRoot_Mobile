import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Continue with Google" sits under the Sign in / Create account forms, as
/// on the website, and not under Forgot password (nothing to continue to).
void main() {
  Future<void> pump(WidgetTester tester) async {
    // A phone-sized, tall surface so the roomier layout fits without scrolling.
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shown on Sign in and Create account, not on Forgot password', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('OR CONTINUE WITH'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(find.text('Continue with Google'), findsNothing);
  });
}
