import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../sync/application/sync_engine.dart';
import 'widgets/home_greeting.dart';
import 'widgets/home_insights_card.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_recent_activity.dart';
import 'widgets/home_snapshot_card.dart';
import 'widgets/home_trackers_section.dart';
import 'widgets/home_upcoming_card.dart';

/// Home — the mobile financial feed (M6). Everything reads from the local
/// cache, so the feed paints immediately and works offline; pull-to-refresh
/// forces a sync. It is a feed, not a shrunk web dashboard: a greeting and
/// trustworthy sync state, one honest snapshot, fast capture, then recent
/// activity, trackers and what's coming.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(syncEngineProvider.notifier).syncNow(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.huge,
            ),
            children: const [
              HomeGreeting(),
              SizedBox(height: AppSpacing.xl),
              HomeSnapshotCard(),
              SizedBox(height: AppSpacing.lg),
              HomeQuickActions(),
              HomeRecentActivity(),
              HomeTrackersSection(),
              SizedBox(height: AppSpacing.xl),
              HomeUpcomingCard(),
              SizedBox(height: AppSpacing.md),
              HomeInsightsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
