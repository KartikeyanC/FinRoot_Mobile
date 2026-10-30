import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/design.dart';
import '../../payment_capture/presentation/detected_payments_banner.dart';
import '../../sync/application/sync_engine.dart';
import 'widgets/home_greeting.dart';
import 'widgets/home_insights_card.dart';
import 'widgets/home_recent_activity.dart';
import 'widgets/home_trackers_section.dart';
import 'widgets/wealth_dashboard.dart';

/// Home — the web dashboard's "Wealth" layout ([WealthDashboard]), followed
/// by the phone's recent activity and trackers. Pull-to-refresh forces a sync.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const gap = SizedBox(height: AppSpacing.lg);
    return Scaffold(
      backgroundColor: context.palette.page,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(syncEngineProvider.notifier).syncNow(force: true),
          child: ContentBounds(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.md,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: const [
                HomeGreeting(),
                SizedBox(height: AppSpacing.xl),
                // The web dashboard's layout first, card for card…
                WealthDashboard(),
                DetectedPaymentsBanner(),
                // …then what only the phone adds: recent activity, trackers
                // and the insights.
                gap,
                HomeRecentActivity(),
                HomeTrackersSection(),
                HomeInsightsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
