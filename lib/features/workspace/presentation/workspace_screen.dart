import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../web_link/presentation/web_link_screen.dart';
import '../application/workspace_providers.dart';
import '../domain/membership.dart';

/// The active workspace, a way to switch between workspaces, and a pointer to
/// the web app for member and plan management (inviting / removing people and
/// plan changes are not done on the phone).
class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final current = ref.watch(currentMembershipProvider);
    final memberships =
        ref.watch(membershipsProvider).value ?? const <Membership>[];
    final usable = memberships.where((m) => m.isUsable).toList();
    final currentId = ref.watch(currentTenantIdProvider);

    return AppPage(
      title: 'Workspace',
      subtitle: 'Who you share your finances with',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          if (current != null)
            MetricCard(
              eyebrow: 'Current workspace',
              figure: current.name,
              status: current.isSuspended
                  ? '${current.role.label} · suspended'
                  : 'Your role: ${current.role.label}',
              statusColor: current.isSuspended
                  ? context.finance.warning
                  : palette.muted,
            )
          else
            const CardEmpty(
              icon: Icons.workspaces_outline,
              title: 'No workspace selected',
              message: 'Sign in again or ask the owner to add you.',
            ),
          if (usable.length > 1) ...[
            const SectionTitle('Switch workspace'),
            for (final m in usable) ...[
              ListRow(
                icon: Icons.workspaces_outline,
                title: m.name,
                subtitle: m.isSuspended
                    ? '${m.role.label} · suspended'
                    : m.role.label,
                trailing: m.tenantId == currentId
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: palette.accentText,
                      )
                    : null,
                onTap: m.tenantId == currentId
                    ? null
                    : () => ref
                          .read(workspaceControllerProvider)
                          .select(m.tenantId),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SectionTitle('Members and plan'),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inviting or removing members and changing your plan are '
                  'managed in the web app.',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.lg),
                PillButton(
                  label: 'Open in browser',
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onPressed: () => openWebAppPage(context, ref, 'workspace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
