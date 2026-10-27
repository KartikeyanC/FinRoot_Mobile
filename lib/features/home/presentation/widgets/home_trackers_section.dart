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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Trackers',
          action: TextButton(
            onPressed: () => context.go(AppDestination.trackers.path),
            child: const Text('See all'),
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (var i = 0; i < active.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TrackerRow(active[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow(this.t);
  final TrackerWithSpend t;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => context.push('/tracker/${t.tracker.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  trackerTypeIcon(t.tracker.type),
                  size: 18,
                  color: context.finance.brandText,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    trackerDisplayLabel(t.tracker.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TrackerProgress(t, compact: true),
          ],
        ),
      ),
    );
  }
}
