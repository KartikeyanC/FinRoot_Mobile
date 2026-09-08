import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';

/// Trackers — an optional contextual dimension on a transaction, never a
/// ledger (web ADR-0010). M9 builds list, detail, spend, assign, review.
///
/// The `trackers` menu is a real paywall on the web (ADR-0002); when it is not
/// in the workspace's effective menus this tab shows a locked state rather than
/// an empty feature.
class TrackersScreen extends ConsumerWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.trackers)) ==
        MenuStatus.locked;

    return Scaffold(
      body: locked
          ? const MenuLockedView(
              feature: 'Trackers',
              icon: Icons.donut_large_outlined,
            )
          : const PlaceholderScreen(
              title: 'Trackers',
              milestone: 'M9',
              icon: Icons.donut_large_outlined,
              showAppBar: false,
            ),
    );
  }
}
