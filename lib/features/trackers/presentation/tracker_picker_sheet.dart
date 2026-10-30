import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../application/trackers_providers.dart';
import '../domain/tracker_draft.dart';

/// Pick an active tracker (e.g. to assign one transaction to it). Returns the
/// chosen tracker id, or null if dismissed.
Future<String?> pickTracker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _TrackerPickerSheet(),
  );
}

class _TrackerPickerSheet extends ConsumerWidget {
  const _TrackerPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Assigning is only meaningful for live projects.
    final active = ref.watch(trackersListProvider).value ?? const [];
    final palette = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign to tracker',
              style: AppTypography.title.copyWith(color: palette.ink),
            ),
            const SizedBox(height: AppSpacing.md),
            if (active.isEmpty)
              const CardEmpty(
                icon: Icons.donut_large_rounded,
                title: 'No active trackers',
                message:
                    'No active trackers. Create one from the Trackers tab '
                    'first.',
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in active)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: ListRow(
                          icon: trackerTypeIcon(t.type),
                          title: trackerDisplayLabel(t.name),
                          subtitle: t.type,
                          chevron: true,
                          onTap: () => Navigator.of(context).pop(t.id),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
