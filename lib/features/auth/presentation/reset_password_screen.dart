import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/error_mapper.dart';
import '../../../design/design.dart';
import '../application/auth_validators.dart';
import '../application/password_recovery.dart';
import '../data/auth_repository.dart';

/// Set a new password after opening the reset link. The link created a
/// short-lived session, so `updateUser({password})` works here; on success the
/// user lands in the app already signed in.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      ref.read(passwordRecoveryProvider.notifier).clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You are signed in.')),
      );
    } catch (error, stack) {
      if (!mounted) return;
      setState(() => _error = mapError(error, stack).message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _cancel() {
    // Backing out drops the recovery flag; the router then applies the normal
    // signed-in / signed-out routing.
    ref.read(passwordRecoveryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New password'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : _cancel,
          tooltip: 'Cancel',
        ),
      ),
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
                    Text('Choose a new password', style: t.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'At least ${AuthValidators.passwordMin} characters. Avoid a '
                      'password you use elsewhere.',
                      style: t.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: AuthValidators.password,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) =>
                          AuthValidators.confirmPassword(v, _password.text),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _error!,
                        style: t.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update password'),
                    ),
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
