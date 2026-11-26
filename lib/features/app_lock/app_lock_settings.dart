import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/design.dart';
import '../privacy/income_privacy.dart' show UnlockResult;
import 'app_lock.dart';

/// Settings → App lock: Off / phone lock / FinRoot PIN, and the grace period.
class AppLockSettingsCard extends ConsumerWidget {
  const AppLockSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appLockProvider);
    final palette = context.palette;
    return AppCard(
      key: const ValueKey('app-lock-settings'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lock with',
            style: AppTypography.label.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          FilterPills<AppLockMode>(
            options: const [
              FilterPill(AppLockMode.off, 'Off'),
              FilterPill(
                AppLockMode.device,
                'Fingerprint or screen lock',
                icon: Icons.fingerprint_rounded,
              ),
              FilterPill(
                AppLockMode.pin,
                'FinRoot PIN',
                icon: Icons.pin_outlined,
              ),
            ],
            selected: s.mode,
            onSelected: (m) => _choose(context, ref, m),
          ),
          if (s.enabled) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Lock when I leave the app',
              style: AppTypography.label.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            FilterPills<int>(
              options: [
                for (final m in graceOptions) FilterPill(m, graceLabel(m)),
              ],
              selected: s.graceMinutes,
              onSelected: (m) => ref.read(appLockProvider.notifier).setGrace(m),
            ),
          ],
          if (s.mode == AppLockMode.pin) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: () => _setPin(context, ref),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Change PIN'),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'A curtain over the screen for a phone that is already signed in, '
            'not encryption: your data is protected by your account on the '
            'server. A forgotten PIN is reset by signing out and in again.',
            style: AppTypography.caption.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    AppLockMode mode,
  ) async {
    final c = ref.read(appLockProvider.notifier);
    final current = ref.read(appLockProvider).mode;
    if (mode == current) return;
    final messenger = ScaffoldMessenger.of(context);
    switch (mode) {
      case AppLockMode.off:
        await c.turnOff();
        messenger.showSnackBar(
          const SnackBar(content: Text('App lock is off')),
        );
      case AppLockMode.device:
        final r = await c.useDeviceLock();
        final msg = switch (r) {
          UnlockResult.ok => 'FinRoot now locks with your phone\'s lock',
          UnlockResult.failed => 'Not confirmed. The app lock is unchanged.',
          UnlockResult.noLock =>
            'Set a screen lock (fingerprint or PIN) on this phone first.',
        };
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      case AppLockMode.pin:
        if (context.mounted) await _setPin(context, ref);
    }
  }

  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const PinSetupDialog(),
    );
    if (pin == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(appLockProvider.notifier).setPin(pin);
    messenger.showSnackBar(const SnackBar(content: Text('FinRoot PIN set')));
  }
}

/// Choose a 4–6 digit PIN (6 by default) and type it twice. Pops the PIN, or
/// null when cancelled.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  int _length = defaultPinLength;
  final _pin = TextEditingController();
  final _again = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _again.dispose();
    super.dispose();
  }

  void _save() {
    final a = _pin.text;
    final b = _again.text;
    String? error;
    if (a.length != _length || !RegExp(r'^\d+$').hasMatch(a)) {
      error = 'Enter $_length digits.';
    } else if (RegExp(r'^(\d)\1+$').hasMatch(a)) {
      error = 'Avoid one digit repeated.';
    } else if (a != b) {
      error = 'The two PINs do not match.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    InputDecoration deco(String label) =>
        InputDecoration(labelText: label, counterText: '');
    TextField field(
      TextEditingController c,
      String label, {
      bool last = false,
    }) => TextField(
      controller: c,
      autofocus: !last,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: _length,
      decoration: deco(label),
      onSubmitted: last ? (_) => _save() : null,
    );
    return AlertDialog(
      title: const Text('Set a FinRoot PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilterPills<int>(
              options: const [
                FilterPill(6, '6 digits'),
                FilterPill(5, '5 digits'),
                FilterPill(4, '4 digits'),
              ],
              selected: _length,
              onSelected: (n) => setState(() {
                _length = n;
                _error = null;
                if (_pin.text.length > n) _pin.text = _pin.text.substring(0, n);
                if (_again.text.length > n) {
                  _again.text = _again.text.substring(0, n);
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            field(_pin, 'PIN'),
            field(_again, 'Type it again', last: true),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Don\'t reuse these digits: not your phone\'s PIN, your bank '
              'card\'s or your UPI PIN. Six digits is the harder one to guess.',
              style: AppTypography.caption.copyWith(color: palette.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                key: const ValueKey('pin-setup-error'),
                style: AppTypography.body.copyWith(
                  color: context.finance.danger,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Set PIN')),
      ],
    );
  }
}
