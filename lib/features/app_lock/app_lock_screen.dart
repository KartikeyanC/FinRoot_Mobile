import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/design.dart';
import '../auth/application/sign_out.dart';
import '../privacy/income_privacy.dart' show UnlockResult;
import 'app_lock.dart';

/// How the lock screen signs out on the forgotten-PIN path. Overridden in
/// tests.
final appLockSignOutProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => ref.read(signOutControllerProvider).signOut(),
  name: 'appLockSignOut',
);

/// Draws the lock screen over the whole app while [AppLockState.locked].
///
/// The app underneath stays mounted (same tree shape either way), so
/// unlocking returns to exactly where the person was. While locked it is
/// hidden from accessibility and its animations are paused.
///
/// The floating Quick Add engine never locks (see [isQuickAddEngineProvider]):
/// it only adds an entry and shows nothing already in the account.
class AppLockGate extends ConsumerWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(appLockProvider.select((s) => s.locked), (_, locked) {
      // Close any keyboard the app underneath had open.
      if (locked) FocusManager.instance.primaryFocus?.unfocus();
    });
    final locked = ref.watch(appLockProvider.select((s) => s.locked));
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: locked,
          child: TickerMode(enabled: !locked, child: child),
        ),
        if (locked) const AppLockScreen(),
      ],
    );
  }
}

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  String? _message;
  bool _busy = false;
  bool _confirmSignOut = false;
  Timer? _ticker;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    final s = ref.read(appLockProvider);
    if (s.mode == AppLockMode.device) {
      // Ask the phone's lock straight away; the button is there to retry.
      WidgetsBinding.instance.addPostFrameCallback((_) => _unlockDevice());
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _shake.dispose();
    super.dispose();
  }

  DateTime _now() => ref.read(appLockClockProvider)();

  Duration? _waitLeft() {
    final until = ref.read(appLockProvider).waitUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    return left > Duration.zero ? left : null;
  }

  /// A one-second tick while PIN entry is paused, to count down and then
  /// re-enable the keys.
  void _syncTicker() {
    _ticker?.cancel();
    if (_waitLeft() == null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_waitLeft() == null) {
        _ticker?.cancel();
        _message = null;
      }
    });
  }

  Future<void> _unlockDevice() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final r = await ref.read(appLockProvider.notifier).unlockWithDevice();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = switch (r) {
        UnlockResult.ok => null,
        UnlockResult.failed => 'Not confirmed. Try again.',
        UnlockResult.noLock =>
          'This phone has no screen lock now. Sign out and sign in again to '
              'open FinRoot.',
      };
    });
  }

  void _press(String digit) {
    if (_busy || _waitLeft() != null) return;
    final len = ref.read(appLockProvider).pinLength;
    if (_entered.length >= len) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _entered += digit;
      _message = null;
    });
    if (_entered.length == len) unawaited(_submit());
  }

  void _backspace() {
    if (_busy || _entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final r = await ref.read(appLockProvider.notifier).submitPin(_entered);
    if (!mounted) return;
    final s = ref.read(appLockProvider);
    setState(() {
      _busy = false;
      _entered = '';
      _message = switch (r) {
        PinCheck.ok => null,
        PinCheck.wrong => () {
          final left = maxPinAttempts - s.failedAttempts;
          return 'Wrong PIN. $left ${left == 1 ? 'try' : 'tries'} left.';
        }(),
        PinCheck.waiting => 'Too many wrong tries.',
      };
    });
    if (r != PinCheck.ok) {
      unawaited(HapticFeedback.heavyImpact());
      unawaited(_shake.forward(from: 0));
      _syncTicker();
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await ref.read(appLockSignOutProvider)();
      await ref.read(appLockProvider.notifier).turnOff();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Could not sign out. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appLockProvider);
    final palette = context.palette;
    final wait = _waitLeft();
    final isPin = s.mode == AppLockMode.pin;

    final Widget body;
    if (_confirmSignOut) {
      body = _SignOutPanel(
        busy: _busy,
        onCancel: () => setState(() => _confirmSignOut = false),
        onConfirm: _signOut,
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 40, color: palette.accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'FinRoot is locked',
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPin
                ? 'Enter your FinRoot PIN'
                : 'Use your fingerprint or phone screen lock',
            style: AppTypography.body.copyWith(color: palette.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (isPin) ...[
            AnimatedBuilder(
              animation: _shake,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  math.sin(_shake.value * math.pi * 6) *
                      12 *
                      (1 - _shake.value),
                  0,
                ),
                child: child,
              ),
              child: _PinDots(
                key: const ValueKey('app-lock-dots'),
                length: s.pinLength,
                filled: _entered.length,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 40,
              child: _busy
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _Message(
                      text: wait != null
                          ? 'Too many wrong tries. Try again in '
                                '${(wait.inMilliseconds / 1000).ceil()} s.'
                          : _message,
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Keypad(
              enabled: !_busy && wait == null,
              onDigit: _press,
              onBackspace: _backspace,
            ),
          ] else ...[
            FilledButton.icon(
              key: const ValueKey('app-lock-device'),
              onPressed: _busy ? null : _unlockDevice,
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Unlock'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(height: 40, child: _Message(text: _message)),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            key: const ValueKey('app-lock-forgot'),
            onPressed: _busy
                ? null
                : () => setState(() => _confirmSignOut = true),
            child: Text(isPin ? 'Forgot your PIN?' : 'Can\'t unlock?'),
          ),
        ],
      );
    }

    return Material(
      color: palette.page,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});
  final String? text;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      text ?? '',
      key: const ValueKey('app-lock-message'),
      textAlign: TextAlign.center,
      style: AppTypography.body.copyWith(color: context.finance.danger),
    ),
  );
}

class _SignOutPanel extends StatelessWidget {
  const _SignOutPanel({
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sign out and sign in again',
          style: AppTypography.title.copyWith(color: palette.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your email and password are what protect your account, so they '
          'are how you get back in. Signing out removes the app lock from '
          'this phone; you can set it again in Settings. Anything not yet '
          'synced finishes on the next sign-in.',
          style: AppTypography.body.copyWith(color: palette.muted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        FilledButton(
          key: const ValueKey('app-lock-signout'),
          style: AppButtonStyles.destructive,
          onPressed: busy ? null : onConfirm,
          child: const Text('Sign out'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: busy ? null : onCancel,
          child: const Text('Back'),
        ),
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({super.key, required this.length, required this.filled});
  final int length;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: '$filled of $length digits entered',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < length; i++)
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < filled ? palette.accent : Colors.transparent,
                border: Border.all(
                  color: i < filled ? palette.accent : palette.muted,
                  width: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _Key(
      key: ValueKey('pin-key-$d'),
      onTap: enabled ? () => onDigit(d) : null,
      child: Text(d, style: AppTypography.title),
    );
    Widget row(List<Widget> keys) =>
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: keys);
    return Column(
      children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          const SizedBox(width: 72, height: 72),
          key('0'),
          _Key(
            key: const ValueKey('pin-key-back'),
            onTap: enabled ? onBackspace : null,
            semanticLabel: 'Delete',
            child: const Icon(Icons.backspace_outlined),
          ),
        ]),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });
  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: palette.card,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: onTap == null ? palette.faint : palette.ink,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: onTap == null ? palette.faint : palette.ink,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
