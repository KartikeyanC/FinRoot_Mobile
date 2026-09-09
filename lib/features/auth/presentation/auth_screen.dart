import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../application/auth_controller.dart';
import '../application/auth_validators.dart';

enum _Mode { signIn, signUp, forgot }

/// Sign in / create account / forgot password.
///
/// Email + password only (decision 4). One screen, three modes — a mobile
/// pattern, not a web page with tabs. The router navigates away on its own when
/// a session appears, so this screen never pushes a route.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchTo(_Mode mode) {
    setState(() => _mode = mode);
    ref.read(authControllerProvider.notifier).reset();
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = ref.read(authControllerProvider.notifier);
    switch (_mode) {
      case _Mode.signIn:
        await controller.signIn(email: _email.text, password: _password.text);
      case _Mode.signUp:
        await controller.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      case _Mode.forgot:
        await controller.sendPasswordReset(_email.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final busy = state is AuthBusy;
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // A confirmation / reset-sent outcome replaces the form with a message.
    if (state is AuthAwaitingConfirmation) {
      return _OutcomeScaffold(
        icon: Icons.mark_email_unread_outlined,
        title: 'Confirm your email',
        message:
            'We sent a confirmation link to ${state.email}. Open it, then '
            'come back and sign in.',
        actionLabel: 'Back to sign in',
        onAction: () => _switchTo(_Mode.signIn),
      );
    }
    if (state is AuthResetEmailSent) {
      return _OutcomeScaffold(
        icon: Icons.lock_reset_outlined,
        title: 'Check your email',
        message:
            'If ${state.email} has an account, a reset link is on its way. '
            'Opening it lets you set a new password.',
        actionLabel: 'Back to sign in',
        onAction: () => _switchTo(_Mode.signIn),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.spa_rounded, size: 44, color: scheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: t.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    if (_mode == _Mode.signUp) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: AuthValidators.name,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: _mode == _Mode.forgot
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: AuthValidators.email,
                    ),

                    if (_mode != _Mode.forgot) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: _mode == _Mode.signUp
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: _mode == _Mode.signUp
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        onFieldSubmitted: (_) {
                          if (_mode == _Mode.signIn) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscure
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                        validator: _mode == _Mode.signUp
                            ? AuthValidators.password
                            : AuthValidators.loginPassword,
                      ),
                    ],

                    if (_mode == _Mode.signUp) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirm,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) =>
                            AuthValidators.confirmPassword(v, _password.text),
                      ),
                    ],

                    if (_mode == _Mode.signIn)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: busy
                              ? null
                              : () => _switchTo(_Mode.forgot),
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    if (state is AuthFailed) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _ErrorBanner(state.failure.message),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_cta),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ModeSwitcher(mode: _mode, busy: busy, onSwitch: _switchTo),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title => switch (_mode) {
    _Mode.signIn => 'Welcome back',
    _Mode.signUp => 'Create your account',
    _Mode.forgot => 'Reset password',
  };

  String get _subtitle => switch (_mode) {
    _Mode.signIn => 'Daily money control, in your pocket.',
    _Mode.signUp => 'One account for web, phone and tablet.',
    _Mode.forgot => 'We\'ll email you a link to set a new one.',
  };

  String get _cta => switch (_mode) {
    _Mode.signIn => 'Sign in',
    _Mode.signUp => 'Create account',
    _Mode.forgot => 'Send reset link',
  };
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({
    required this.mode,
    required this.busy,
    required this.onSwitch,
  });

  final _Mode mode;
  final bool busy;
  final void Function(_Mode) onSwitch;

  @override
  Widget build(BuildContext context) {
    if (mode == _Mode.forgot) {
      return TextButton(
        onPressed: busy ? null : () => onSwitch(_Mode.signIn),
        child: const Text('Back to sign in'),
      );
    }
    final toSignUp = mode == _Mode.signIn;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          toSignUp ? 'New to FinRoot?' : 'Already have an account?',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => onSwitch(toSignUp ? _Mode.signUp : _Mode.signIn),
          child: Text(toSignUp ? 'Create account' : 'Sign in'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _OutcomeScaffold extends StatelessWidget {
  const _OutcomeScaffold({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    style: t.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
