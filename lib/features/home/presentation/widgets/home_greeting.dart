import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/providers.dart';
import '../../../../design/design.dart';
import '../../../privacy/income_privacy.dart';
import '../../../profile/profile_providers.dart';
import '../../../sync/presentation/sync_status_widgets.dart';
import '../../../workspace/application/workspace_providers.dart';
import '../../../workspace/domain/membership.dart';
import '../../../workspace/presentation/workspace_switcher_sheet.dart';

/// The top of Home, NineFlow style: a round workspace pill (avatar, name,
/// chevron) with the sync state beside it, then a big bold greeting with
/// today's date in muted text under it.
class HomeGreeting extends ConsumerWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    final profile = ref.watch(profileProvider).value;
    final email = ref.watch(currentUserProvider)?.email;
    final name = _firstName(profile?.displayName) ?? _localPart(email);
    final workspace = ref.watch(currentMembershipProvider)?.name;
    final count = (ref.watch(membershipsProvider).value ?? const <Membership>[])
        .where((m) => m.isUsable)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The pill takes the room it needs; the sync chip keeps its natural
        // width (capped, so a long sync message ellipsizes instead) and the
        // pill only ellipsizes when the two truly don't fit.
        LayoutBuilder(
          builder: (context, c) => HitSlop(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                if (workspace != null) ...[
                  Flexible(
                    child: _WorkspacePill(
                      name: workspace,
                      onTap: count > 1
                          ? () => showWorkspaceSwitcher(context)
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * 0.45),
                  child: const SyncStatusChip(),
                ),
                const Spacer(),
                const IncomePrivacyButton(),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            name == null ? 'Welcome back' : '${_timeGreeting()}, $name',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display.copyWith(color: palette.ink),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('EEEE, d MMMM').format(DateTime.now()),
          style: AppTypography.body.copyWith(color: palette.muted),
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

class _WorkspacePill extends StatelessWidget {
  const _WorkspacePill({required this.name, required this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    // Drawn 40dp tall; answers taps at 48dp.
    return HitSlop(
      expandSemantics: true,
      child: Semantics(
        button: onTap != null,
        label: 'Workspace $name',
        child: Material(
          color: palette.card,
          shape: StadiumBorder(side: BorderSide(color: palette.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.gradient,
                    ),
                    child: Text(
                      initial,
                      style: AppTypography.label.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: palette.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
