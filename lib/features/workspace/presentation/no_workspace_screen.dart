import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../auth/application/sign_out.dart';
import '../application/workspace_providers.dart';

/// Signed in, but no usable workspace. Rare — the signup trigger always creates
/// a personal one — so this reads as "something is off", with a retry and a way
/// out, not a dead end (M1 audit §14 route guard).
class NoWorkspaceScreen extends ConsumerWidget {
  const NoWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(membershipsProvider);
    final retrying = memberships.isLoading;

    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconTile(icon: Icons.workspaces_outline, size: 56),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'No workspace found',
                  style: AppTypography.display.copyWith(
                    color: palette.ink,
                    fontSize: 24,
                    height: 32 / 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This account is signed in but has no workspace yet. This is '
                  'unusual — retrying usually fixes it. If it keeps happening, '
                  'open FinRoot on the web once, then try again here.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: retrying
                      ? null
                      : () => ref
                            .read(workspaceControllerProvider)
                            .refreshMemberships(),
                  icon: retrying
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: () =>
                      ref.read(signOutControllerProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
