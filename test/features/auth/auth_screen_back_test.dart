import 'package:finroot_mobile/design/design.dart';
import 'package:finroot_mobile/features/auth/presentation/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sign in / Create account / Forgot password share one route, so the system
/// Back used to close the app from "Create account" (found on the first
/// emulator run). Back now returns to the sign-in form.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const AuthScreen()),
      ),
    );
    await tester.pump();
  }

  Future<bool> systemBack(WidgetTester tester) async {
    final popped = await tester.binding.handlePopRoute();
    await tester.pump();
    return popped;
  }

  testWidgets('Back from Create account returns to Sign in', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);

    expect(await systemBack(tester), isTrue, reason: 'Back was handled');
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Back from Forgot password returns to Sign in', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();
    expect(find.text('Welcome back'), findsNothing);

    expect(await systemBack(tester), isTrue);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('Back on Sign in is left to the system', (tester) async {
    await pump(tester);
    // Nothing in the app consumes it, so Android may close the app as usual.
    expect(await systemBack(tester), isFalse);
  });
}
