import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design/design.dart';
import '../../../../domain/constants.dart';
import '../../../../navigation/destinations.dart';
import '../../../menus/application/menu_providers.dart';
import '../../../trackers/domain/tracker.dart';
import '../../application/home_providers.dart';

/// Active trackers on the feed. Hidden entirely when the trackers menu is
/// locked for the workspace (the Trackers tab owns the locked state) or when
/// there are none — trackers are an optional dimension (ADR-0010), not
/// something to nag about on Home.
///
/// Shows the name, type and the server-set budget only. Spend / progress is
/// server-derived and arrives in M9.
class HomeTrackersSection extends ConsumerWidget {
  const HomeTrackersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.trackers)) ==
        MenuStatus.locked;
    if (locked) return const SizedBox.shrink();

    final trackers = ref.watch(activeTrackersProvider).value ?? const [];
    if (trackers.isEmpty) return const SizedBox.shrink();

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
              for (var i = 0; i < trackers.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TrackerRow(trackers[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow(this.tracker);
  final TrackerEntity tracker;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSpacing.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.donut_large_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trackerDisplayLabel(tracker.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tracker.type,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (tracker.budget != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText.money(tracker.budget!, signed: false),
                  const SizedBox(height: 2),
                  Text(
                    'budget',
                    style: t.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
