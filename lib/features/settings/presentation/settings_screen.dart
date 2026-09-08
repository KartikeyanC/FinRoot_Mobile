import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_prefs.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/profile_providers.dart';
import '../../workspace/presentation/workspace_switcher_sheet.dart';

/// Settings — profile, workspace, appearance, sign-out.
///
/// App lock (PIN / biometric) is a later phase, not M3 — it is a device
/// curtain over the screen, not access control (web ADR-0007), and worth
/// building on its own.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionLabel('Profile'),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(
              profile.value?.displayName ??
                  user?.userMetadata?['display_name'] as String? ??
                  'Your name',
            ),
            subtitle: const Text('Display name'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editName(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(user?.email ?? '—'),
            subtitle: const Text('Email'),
          ),

          const Divider(height: 1),
          const _SectionLabel('Workspace'),
          const WorkspaceSummaryTile(),

          const Divider(height: 1),
          const _SectionLabel('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: themeMode,
            onChanged: (mode) {
              if (mode != null) {
                ref.read(themeModeProvider.notifier).set(mode);
              }
            },
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  title: Text('Follow system'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  title: Text('Light'),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  title: Text('Dark'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          const _SectionLabel('Account'),
          ListTile(
            leading: Icon(
              Icons.logout,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Sign out',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final current = ref.read(profileProvider).value?.displayName ?? '';
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == current) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(profileControllerProvider).updateDisplayName(newName);
      messenger.showSnackBar(const SnackBar(content: Text('Name updated')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not update your name. Try again.')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign back in. Anything '
          'not yet synced will finish on the next sign-in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
