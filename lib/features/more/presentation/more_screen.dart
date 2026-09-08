import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../../navigation/destinations.dart';
import '../../menus/application/menu_providers.dart';
import '../../workspace/presentation/workspace_switcher_sheet.dart';

/// "More" — secondary features via progressive disclosure (brief §5).
///
/// Entries whose feature is not in the workspace's effective menus
/// (`get_effective_menus`) render locked rather than hidden: a person who
/// expects a feature should see it is unavailable here, not wonder where it
/// went. No upgrade prompt yet — distinguishing a plan lock from an
/// owner-disabled menu is the billing phase's job (web `menuUpsell`).
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          const WorkspaceSummaryTile(),
          const Divider(height: 1, indent: 56),
          for (final e in kMoreEntries) _MoreTile(entry: e),
        ],
      ),
    );
  }
}

class _MoreTile extends ConsumerWidget {
  const _MoreTile({required this.entry});
  final MoreEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = entry.menu == null
        ? MenuStatus.available
        : ref.watch(menuStatusProvider(entry.menu!));
    final locked = status == MenuStatus.locked;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(entry.icon, color: locked ? scheme.onSurfaceVariant : null),
      title: Text(
        entry.label,
        style: locked ? TextStyle(color: scheme.onSurfaceVariant) : null,
      ),
      trailing: _trailing(context, locked),
      onTap: locked
          ? () => _showLocked(context)
          : () => context.push(entry.route),
    );
  }

  Widget _trailing(BuildContext context, bool locked) {
    if (locked) return const Icon(Icons.lock_outline, size: 18);
    if (entry.phase != null) {
      return Text(
        entry.phase!,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return const Icon(Icons.chevron_right);
  }

  void _showLocked(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.icon,
                size: 32,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${entry.label} isn\'t available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This feature is turned off for the current workspace. A '
                'workspace owner can change what\'s available on the web app.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
