import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/providers.dart';
import '../../../../design/design.dart';
import '../../../profile/profile_providers.dart';
import '../../../sync/presentation/sync_status_widgets.dart';
import '../../../workspace/application/workspace_providers.dart';

/// The feed's opening line: a time-of-day greeting, who you are, which workspace
/// you're in, and the sync state — the first thing a person should be able to
/// trust on a finance app.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final profile = ref.watch(profileProvider).value;
    final email = ref.watch(currentUserProvider)?.email;
    final name = _firstName(profile?.displayName) ?? _localPart(email);
    final workspace = ref.watch(currentMembershipProvider)?.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timeGreeting(),
          style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          name ?? 'Welcome back',
          style: t.headlineSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            if (workspace != null) ...[
              Icon(
                Icons.workspaces_outline,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  workspace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            const Flexible(child: SyncStatusChip()),
          ],
        ),
      ],
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String? _firstName(String? displayName) {
    final trimmed = displayName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String? _localPart(String? email) {
    if (email == null || !email.contains('@')) return null;
    return email.split('@').first;
  }
}
