import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../application/workspace_providers.dart';
import '../domain/membership.dart';

/// Bottom sheet to switch the active workspace. Only shown when the user is in
/// more than one (the web has a switcher; a single-workspace user needs no UI).
Future<void> showWorkspaceSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _WorkspaceSwitcherSheet(),
  );
}

class _WorkspaceSwitcherSheet extends ConsumerWidget {
  const _WorkspaceSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships =
        ref.watch(membershipsProvider).value ?? const <Membership>[];
    final currentId = ref.watch(currentTenantIdProvider);
    final usable = memberships.where((m) => m.isUsable).toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Switch workspace',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final m in usable)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                child: Text(_initial(m.name)),
              ),
              title: Text(m.name),
              subtitle: Text(
                m.isSuspended ? '${m.role.label} · suspended' : m.role.label,
              ),
              trailing: m.tenantId == currentId
                  ? Icon(
                      Icons.check_circle,
                      color: context.finance.brandText,
                    )
                  : null,
              onTap: m.tenantId == currentId
                  ? null
                  : () async {
                      await ref
                          .read(workspaceControllerProvider)
                          .select(m.tenantId);
                      if (context.mounted) Navigator.of(context).pop();
                    },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

/// A compact current-workspace summary for the Settings header.
class WorkspaceSummaryTile extends ConsumerWidget {
  const WorkspaceSummaryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider);
    final count = (ref.watch(membershipsProvider).value ?? const <Membership>[])
        .where((m) => m.isUsable)
        .length;
    if (membership == null) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.workspaces_outline),
      title: Text(membership.name),
      subtitle: Text(membership.role.label),
      trailing: count > 1 ? const Icon(Icons.unfold_more) : null,
      onTap: count > 1 ? () => showWorkspaceSwitcher(context) : null,
    );
  }
}
