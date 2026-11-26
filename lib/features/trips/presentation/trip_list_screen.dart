import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_format.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../split/presentation/split_state_views.dart';
import '../../web_link/presentation/web_link_screen.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';
import 'new_trip_screen.dart';

/// Trips — the web's trip sandboxes, on the phone: plan a new one, open it,
/// log and edit expenses, settle up. Menu-gated. Online-only (not cached).
class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  static const route = '/trips';
  static String detailRoute(String id) => '/trips/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(menuStatusProvider(FeatureMenu.trips)) == MenuStatus.locked) {
      return const AppPage(
        title: 'Trips',
        body: MenuLockedView(feature: 'Trips', icon: Icons.luggage_outlined),
      );
    }
    final online = ref.watch(isOnlineProvider);
    final trips = ref.watch(tripsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    Future<void> newTrip() async {
      final id = await openNewTripScreen(context);
      if (id != null && context.mounted) {
        await context.push(TripListScreen.detailRoute(id));
      }
    }

    return AppPage(
      title: 'Trips',
      padBody: false,
      floatingActionButton: canWrite && online
          ? AddFab(label: 'New trip', onPressed: newTrip)
          : null,
      actions: [
        IconButton(
          tooltip: 'Open Trips on the web',
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: () => openWebAppPage(context, ref, 'trips'),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tripsProvider),
        child: !online && !trips.hasValue
            ? const _Scrollable(child: OnlineOnlyView(feature: 'Trips'))
            : trips.when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    ErrorView(e, onRetry: () => ref.invalidate(tripsProvider)),
                data: (list) => list.isEmpty
                    ? _Scrollable(
                        child: EmptyView(
                          icon: Icons.luggage_outlined,
                          title: 'No trips yet',
                          message: canWrite
                              ? 'Plan a trip budget: fund it from your '
                                    'accounts, log spends, settle up with '
                                    'friends.'
                              : 'Trips planned in this workspace show here.',
                          action: canWrite && online
                              ? PillButton(
                                  label: 'New trip',
                                  icon: Icons.add_rounded,
                                  onPressed: newTrip,
                                )
                              : null,
                        ),
                      )
                    : _TripList(trips: list),
              ),
      ),
    );
  }
}

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(height: c.maxHeight, child: child),
    ),
  );
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    final active = trips.where((t) => !t.isArchived).toList();
    final archived = trips.where((t) => t.isArchived).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        if (active.isNotEmpty) ...[
          const SectionTitle('Active'),
          for (final t in active) _TripCard(trip: t),
        ],
        if (archived.isNotEmpty) ...[
          const SectionTitle('Archived'),
          for (final t in archived) _TripCard(trip: t),
        ],
      ],
    );
  }
}

IconData tripKindIcon(String kind) => switch (kind) {
  'solo' => Icons.person_outline,
  'friends' => Icons.groups_outlined,
  'family' => Icons.family_restroom_outlined,
  _ => Icons.flag_outlined,
};

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tot = TripTotals.of(trip);
    final pct = tot.allocated > 0
        ? (tot.paidByYou / tot.allocated).clamp(0.0, 1.0)
        : 0.0;
    final over = tot.allocated > 0 && tot.paidByYou > tot.allocated;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => context.push(TripListScreen.detailRoute(trip.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconTile(icon: tripKindIcon(trip.kind), size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        [
                          trip.kindLabel,
                          if (trip.currency != 'INR') trip.currency,
                          if (trip.companions.isNotEmpty)
                            '${trip.companions.length} with you',
                          '${trip.expenses.length} spends',
                        ].join(' · '),
                        style: AppTypography.caption.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.faint),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: palette.line,
                color: over ? context.finance.expense : palette.accent,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Spent ${MoneyFormat.money(tot.spent, currency: trip.currency)}'
              ' of '
              '${MoneyFormat.money(tot.allocated, currency: trip.currency)}',

              style: AppTypography.caption.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
