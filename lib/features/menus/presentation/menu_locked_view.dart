import 'package:flutter/material.dart';

import '../../../design/design.dart';

/// Shown in place of a feature screen when the workspace's effective menus do
/// not include it. Not a crash, not a raw error, no upgrade prompt yet
/// (web `menuUpsell`: only a plan lock may advertise an upgrade, and that
/// distinction is the billing phase's).
class MenuLockedView extends StatelessWidget {
  const MenuLockedView({super.key, required this.feature, this.icon});

  final String feature;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.sm,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        CardEmpty(
          icon: icon ?? Icons.lock_outline_rounded,
          title: '$feature isn\'t available',
          message:
              'This feature is turned off for the current workspace. A '
              'workspace owner can switch it on from the web app.',
        ),
      ],
    );
  }
}
