import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../reminders/presentation/status_tones.dart';
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
    // The three modes (and the outcome messages) share one route, so the
    // system Back would close the app from "Create account". Anywhere but the
    // plain sign-in form, Back returns to sign-in instead.
    final atSignIn =
        _mode == _Mode.signIn &&
        state is! AuthAwaitingConfirmation &&
        state is! AuthResetEmailSent;
    return PopScope(
      canPop: atSignIn,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state is! AuthBusy) _switchTo(_Mode.signIn);
      },
      child: _content(context, state),
    );
  }

  Widget _content(BuildContext context, AuthActionState state) {
    final busy = state is AuthBusy;
    final palette = context.palette;

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
      backgroundColor: palette.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Lockup(),
                    const SizedBox(height: AppSpacing.xxxl),
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: AppTypography.display.copyWith(color: palette.ink),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),

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
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(state.failure.message),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_cta),
                    ),
                    if (_mode != _Mode.forgot) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _OrDivider(),
                      const SizedBox(height: AppSpacing.xl),
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithGoogle(),
                        icon: const _GoogleMark(),
                        label: const Text('Continue with Google'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
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

/// "— or continue with —", as on the website's sign-in card.
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final line = context.palette.line;
    return Row(
      children: [
        Expanded(child: Divider(color: line)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Eyebrow('or continue with'),
        ),
        Expanded(child: Divider(color: line)),
      ],
    );
  }
}

/// Google's four-colour "G", drawn — no asset, no extra package.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(18, 18), painter: _GoogleMarkPainter());
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(center: c, radius: r - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Arcs, clockwise from the 3 o'clock gap: red, yellow, green, blue.
    const colours = [
      Color(0xFFEA4335),
      Color(0xFFFBBC05),
      Color(0xFF34A853),
      Color(0xFF4285F4),
    ];
    const starts = [-0.35, 0.95, 2.1, 3.6]; // radians, roughly
    const sweeps = [1.3, 1.15, 1.5, 1.6];
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        starts[i] + 3.14159 * 0.5 + 2.3,
        sweeps[i],
        false,
        paint..color = colours[i],
      );
    }
    // The blue bar into the centre.
    canvas.drawLine(
      Offset(r, r),
      Offset(size.width - stroke / 2, r),
      paint
        ..color = colours[3]
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(_GoogleMarkPainter old) => false;
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
    // Wrap, not Row — the prompt + button don't fit one line on a small phone
    // or at a large text scale.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          toSignUp ? 'New to FinRoot?' : 'Already have an account?',
          style: AppTypography.body.copyWith(color: context.palette.muted),
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
    final tone = StatusTone.coral(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: AppRadius.field,
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 20, color: tone.foreground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: AppTypography.bodyStrong.copyWith(
                  color: tone.foreground,
                ),
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
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconTile(icon: icon, size: 56),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      title,
                      style: AppTypography.display.copyWith(
                        color: palette.ink,
                        fontSize: 24,
                        height: 32 / 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The FinRoot mark (same image as the launcher icon) with the wordmark.
class _Lockup extends StatelessWidget {
  const _Lockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/brand/logo.png',
            width: 52,
            height: 52,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          'FinRoot',
          style: AppTypography.display.copyWith(
            color: context.palette.ink,
            fontSize: 26,
            height: 32 / 26,
          ),
        ),
      ],
    );
  }
}
