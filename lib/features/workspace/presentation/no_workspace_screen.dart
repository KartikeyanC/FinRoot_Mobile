import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../auth/data/auth_repository.dart';
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.workspaces_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No workspace found',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This account is signed in but has no workspace yet. This is '
                  'unusual — retrying usually fixes it. If it keeps happening, '
                  'open FinRoot on the web once, then try again here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
