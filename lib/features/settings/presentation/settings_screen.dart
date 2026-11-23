import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/device/device_prefs.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../auth/application/sign_out.dart';
import '../../home/presentation/home_layout_screen.dart';
import '../../more/presentation/workspace_row.dart';
import '../../profile/profile_providers.dart';

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
    final palette = context.palette;

    final name =
        profile.value?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        'Your name';

    return AppPage(
      title: 'Settings',
      subtitle: 'Your profile, workspace and look',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          const SectionTitle('Profile'),
          ListRow(
            icon: Icons.badge_outlined,
            title: name,
            subtitle: 'Display name',
            trailing: Icon(Icons.edit_outlined, size: 20, color: palette.muted),
            onTap: () => _editName(context, ref),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListRow(
            icon: Icons.mail_outline_rounded,
            title: user?.email ?? '—',
            subtitle: 'Email',
          ),

          const SectionTitle('Workspace'),
          const MoreWorkspaceRow(),

          const SectionTitle('Appearance'),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode',
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.md),
                FilterPills<ThemeMode>(
                  options: const [
                    FilterPill(ThemeMode.light, 'Light', icon: Icons.light_mode_outlined),
                    FilterPill(ThemeMode.dark, 'Dark', icon: Icons.dark_mode_outlined),
                    FilterPill(ThemeMode.system, 'System'),
                  ],
                  selected: themeMode,
                  onSelected: (mode) =>
                      ref.read(themeModeProvider.notifier).set(mode),
                ),
                const SizedBox(height: AppSpacing.xl),
                const _ColorThemePicker(),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ListRow(
            icon: Icons.dashboard_customize_outlined,
            title: 'Home screen',
            subtitle: 'Choose and order the cards on Home',
            chevron: true,
            onTap: () => context.push(HomeLayoutScreen.route),
          ),

          const SectionTitle('Account'),
          ListRow(
            leading: IconTile(
              icon: Icons.logout_rounded,
              tint: context.finance.danger.withValues(alpha: 0.14),
              color: context.finance.danger,
            ),
            title: 'Sign out',
            subtitle: 'You will need your email and password to sign back in',
            onTap: () => _confirmSignOut(context, ref),
          ),
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
          OutlinedButton(
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
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need your email and password to sign back in. Anything '
          'not yet synced will finish on the next sign-in.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: AppButtonStyles.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      try {
        await ref.read(signOutControllerProvider).signOut();
      } on Object {
        // signOut() only rethrows if the local cache wipe itself failed — rare,
        // and the session is already gone. Tell the user plainly.
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Signed out, but clearing local data ran into a problem. '
              'Reopen the app to finish.',
            ),
          ),
        );
      }
    }
  }
}

/// Colour theme: five swatches (NineFlow's themes), each showing its gradient
/// in the current mode. Independent of light / dark above.
class _ColorThemePicker extends ConsumerWidget {
  const _ColorThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(colorThemeProvider);
    final brightness = Theme.of(context).brightness;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colour theme',
          style: AppTypography.label.copyWith(color: palette.muted),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final theme in AppColorTheme.values)
              _Swatch(
                theme: theme,
                colors: theme.palette(brightness),
                selected: theme == current,
                onTap: () => ref.read(colorThemeProvider.notifier).set(theme),
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.theme,
    required this.colors,
    required this.selected,
    required this.onTap,
  });

  final AppColorTheme theme;
  final AppPalette colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} colour theme',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.tile,
        child: SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? palette.accent : palette.line,
                      width: 2,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: colors.gradient,
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  theme.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? palette.accentText : palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
