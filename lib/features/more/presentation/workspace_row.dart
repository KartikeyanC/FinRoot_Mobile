import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../workspace/application/workspace_providers.dart';
import '../../workspace/domain/membership.dart';
import '../../workspace/presentation/workspace_switcher_sheet.dart';

/// The current workspace as a card row; opens the switcher when there is more
/// than one. Also used at the top of Settings.
class MoreWorkspaceRow extends ConsumerWidget {
  const MoreWorkspaceRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(currentMembershipProvider);
    if (membership == null) return const SizedBox.shrink();
    final count = (ref.watch(membershipsProvider).value ?? const <Membership>[])
        .where((m) => m.isUsable)
        .length;
    final palette = context.palette;
    final initial = membership.name.trim().isEmpty
        ? '?'
        : membership.name.trim()[0].toUpperCase();
    return ListRow(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: AppRadius.tile,
          gradient: palette.gradient,
        ),
        child: Text(
          initial,
          style: AppTypography.title.copyWith(color: Colors.white),
        ),
      ),
      title: membership.name,
      subtitle: membership.role.label,
      trailing: count > 1
          ? Icon(Icons.unfold_more_rounded, color: palette.faint)
          : null,
      onTap: count > 1 ? () => showWorkspaceSwitcher(context) : null,
    );
  }
}
