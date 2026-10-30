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

    final palette = context.palette;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch workspace',
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick the household or business to work in.',
              style: AppTypography.body.copyWith(color: palette.muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final m in usable) ...[
              _WorkspaceRow(
                membership: m,
                active: m.tenantId == currentId,
                initial: _initial(m.name),
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
          ],
        ),
      ),
    );
  }

  String _initial(String name) =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

class _WorkspaceRow extends StatelessWidget {
  const _WorkspaceRow({
    required this.membership,
    required this.active,
    required this.initial,
    required this.onTap,
  });

  final Membership membership;
  final bool active;
  final String initial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final m = membership;
    return AppCard(
      color: active ? palette.tint : null,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? null : palette.subtle,
              gradient: active ? palette.gradient : null,
            ),
            child: Text(
              initial,
              style: AppTypography.bodyStrong.copyWith(
                color: active ? Colors.white : palette.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
                Text(
                  m.isSuspended
                      ? '${m.role.label} · suspended'
                      : m.role.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (active) ...[
            const SizedBox(width: AppSpacing.md),
            Icon(Icons.check_circle_rounded, color: palette.accentText),
          ],
        ],
      ),
    );
  }
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

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenGutter,
        vertical: AppSpacing.xs,
      ),
      child: ListRow(
      icon: Icons.workspaces_outline,
      title: membership.name,
      subtitle: membership.role.label,
      trailing: count > 1
          ? Icon(Icons.unfold_more_rounded, color: context.palette.muted)
          : null,
      onTap: count > 1 ? () => showWorkspaceSwitcher(context) : null,
      ),
    );
  }
}
