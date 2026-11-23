import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../payment_capture/presentation/detected_payments_banner.dart';
import '../../sync/application/sync_engine.dart';
import '../application/home_layout_controller.dart';
import '../domain/home_layout.dart';
import 'home_layout_screen.dart';
import 'widgets/home_greeting.dart';
import 'widgets/home_insights_card.dart';
import 'widgets/home_recent_activity.dart';
import 'widgets/home_trackers_section.dart';
import 'widgets/wealth_dashboard.dart';

/// Home — the web dashboard's "Wealth" cards ([WealthBlock]) and the phone's
/// recent activity, trackers and insights, in the order the person chose
/// ([homeLayoutProvider]; "Customize home", or long-press a card). The
/// greeting and the payments-to-review banner stay on top. Pull-to-refresh
/// forces a sync.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    // Only the cards that draw something, so the gaps stay even.
    final blocks = [
      for (final b in layout.visible)
        if (_shows(ref, b)) b,
    ];

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
              children: [
                const HomeGreeting(),
                const SizedBox(height: AppSpacing.xl),
                const DetectedPaymentsBanner(),
                if (blocks.isEmpty)
                  CardEmpty(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'All Home cards are off',
                    message: 'Turn some back on to see your money here.',
                    actionLabel: 'Customize home',
                    onAction: () => openHomeLayout(context),
                  ),
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i > 0) gap,
                  _HomeCard(blocks[i], key: ValueKey(blocks[i])),
                ],
                if (blocks.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  const _CustomizeButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _shows(WidgetRef ref, HomeBlock b) => switch (b) {
    HomeBlock.recent => true,
    HomeBlock.trackers => homeTrackersShow(ref),
    HomeBlock.insights => homeInsightsShow(ref),
    _ => wealthBlockShows(ref, b),
  };
}

/// Opens "Customize home".
void openHomeLayout(BuildContext context) =>
    context.push(HomeLayoutScreen.route);

/// One card. A long press opens "Customize home", like a phone's own home
/// screen.
class _HomeCard extends StatelessWidget {
  const _HomeCard(this.block, {super.key});

  final HomeBlock block;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        openHomeLayout(context);
      },
      child: switch (block) {
        HomeBlock.recent => const HomeRecentActivity(),
        HomeBlock.trackers => const HomeTrackersSection(),
        HomeBlock.insights => const HomeInsightsCard(),
        _ => WealthBlock(block),
      },
    );
  }
}

class _CustomizeButton extends StatelessWidget {
  const _CustomizeButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: () => openHomeLayout(context),
        icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
        label: const Text('Customize home'),
      ),
    );
  }
}
