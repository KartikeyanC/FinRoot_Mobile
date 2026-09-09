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
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.sm,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Text('Assign to tracker', style: tt.titleLarge),
            ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No active trackers. Create one from the Trackers tab first.',
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in active)
                      ListTile(
                        leading: Icon(trackerTypeIcon(t.type)),
                        title: Text(trackerDisplayLabel(t.name)),
                        subtitle: Text(t.type),
                        onTap: () => Navigator.of(context).pop(t.id),
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
