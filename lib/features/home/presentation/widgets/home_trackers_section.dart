import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../../navigation/destinations.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../trackers/application/trackers_providers.dart';
import '../../../trackers/domain/tracker_draft.dart';
import '../../../trackers/domain/tracker_spend.dart';
import '../../../trackers/presentation/widgets/tracker_progress.dart';
import 'home_parts.dart';

/// Active trackers on the feed, with spend against budget. Hidden when the
/// trackers menu is locked (the tab owns that state) or when there are none —
/// trackers are an optional dimension (ADR-0010), not something to nag about.
class HomeTrackersSection extends ConsumerWidget {
  const HomeTrackersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.trackers)) ==
        MenuStatus.locked;
    if (locked) return const SizedBox.shrink();

    final all = ref.watch(trackersWithSpendProvider).value ?? const [];
    final active = all
        .where((t) => t.tracker.status == 'active')
        .take(3)
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return HomeSection(
      title: 'Trackers',
      trailing: HomeSeeAll(
        onPressed: () => context.go(AppDestination.trackers.path),
      ),
      child: Column(
        children: [
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: HomeDivider(),
              ),
            _TrackerRow(active[i]),
          ],
        ],
      ),
    );
  }
}

/// Whether [HomeTrackersSection] draws anything: the menu is open and at least
/// one tracker is active.
bool homeTrackersShow(WidgetRef ref) =>
    ref.watch(menuStatusProvider(FeatureMenu.trackers)) != MenuStatus.locked &&
    (ref.watch(trackersWithSpendProvider).value ?? const []).any(
      (t) => t.tracker.status == 'active',
    );

class _TrackerRow extends StatelessWidget {
  const _TrackerRow(this.t);
  final TrackerWithSpend t;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return InkWell(
      onTap: () => context.push('/tracker/${t.tracker.id}'),
      borderRadius: AppRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconTile(icon: trackerTypeIcon(t.tracker.type), size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  trackerDisplayLabel(t.tracker.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TrackerProgress(t, compact: true),
        ],
      ),
    );
  }
}
