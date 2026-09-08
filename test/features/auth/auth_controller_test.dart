import 'package:finroot_mobile/core/error/failure.dart';
import 'package:finroot_mobile/features/auth/application/auth_controller.dart';
import 'package:finroot_mobile/features/auth/data/auth_intent.dart';
import 'package:finroot_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  AuthController controller() =>
      container.read(authControllerProvider.notifier);
  AuthActionState state() => container.read(authControllerProvider);
  AuthIntent intent() => container.read(authIntentProvider);

  test('starts idle', () {
    expect(state(), isA<AuthIdle>());
  });

  test(
    'signIn success → idle, and the sign-in intent is left marked',
    () async {
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {});

      await controller().signIn(email: 'a@b.com', password: 'secret12');

      expect(state(), isA<AuthIdle>());
      // A later app-lock consumes this; the controller must not.
      expect(intent().isPending, isTrue);
    },
  );

  test(
    'signIn failure → AuthFailed with a mapped message, intent cleared',
    () async {
      when(
        () => repo.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const AuthFailure('Sign-in failed. Check your email and password.'),
      );

      await controller().signIn(email: 'a@b.com', password: 'wrong');

      final s = state();
      expect(s, isA<AuthFailed>());
      expect((s as AuthFailed).failure.message, contains('Check your email'));
      expect(intent().isPending, isFalse);
    },
  );

  test('signUp needing confirmation → AuthAwaitingConfirmation', () async {
    when(
      () => repo.signUp(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const SignUpOutcome(needsEmailConfirmation: true),
    );

    await controller().signUp(
      name: 'Aji',
      email: 'a@b.com',
      password: 'secret12',
    );

    final s = state();
    expect(s, isA<AuthAwaitingConfirmation>());
    expect((s as AuthAwaitingConfirmation).email, 'a@b.com');
    expect(intent().isPending, isFalse);
  });

  test('signUp with an immediate session → idle (router takes over)', () async {
    when(
      () => repo.signUp(
        name: any(named: 'name'),
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const SignUpOutcome(needsEmailConfirmation: false),
    );

    await controller().signUp(
      name: 'Aji',
      email: 'a@b.com',
      password: 'secret12',
    );

    expect(state(), isA<AuthIdle>());
  });

  test('sendPasswordReset success → AuthResetEmailSent', () async {
    when(() => repo.sendPasswordReset(any())).thenAnswer((_) async {});

    await controller().sendPasswordReset('a@b.com');

    final s = state();
    expect(s, isA<AuthResetEmailSent>());
    expect((s as AuthResetEmailSent).email, 'a@b.com');
  });

  test('reset() returns to idle from a failed state', () async {
    when(
      () => repo.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const UnexpectedFailure());
    await controller().signIn(email: 'a@b.com', password: 'x');
    expect(state(), isA<AuthFailed>());

    controller().reset();
    expect(state(), isA<AuthIdle>());
  });
}
