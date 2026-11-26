import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money_format.dart';
import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../split/domain/split_dues.dart';
import '../../split/presentation/split_state_views.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/trips_providers.dart';
import '../domain/trip.dart';
import 'trip_expense_sheet.dart';
import 'trip_settle_up_card.dart';

/// Account name for a trip's account id (web tripMeta.fallbackAccount).
String tripAccountName(String id, Map<String, String> names) {
  if (id == kTripCashAccountId) return 'Physical Cash';
  if (id == '_legacy_card') return 'Card (legacy)';
  if (id == '_legacy_wallet') return 'Wallet (legacy)';
  return names[id] ?? 'Removed account';
}

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(menuStatusProvider(FeatureMenu.trips)) == MenuStatus.locked) {
      return const AppPage(
        title: 'Trip',
        body: MenuLockedView(feature: 'Trips', icon: Icons.luggage_outlined),
      );
    }
    final online = ref.watch(isOnlineProvider);
    final async = ref.watch(tripProvider(tripId));
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;
    final trip = async.value;
    final names = {
      for (final a
          in ref.watch(workspaceAccountsProvider).value ??
              const <AccountEntity>[])
        a.id: a.name,
    };

    return AppPage(
      title: trip?.name ?? 'Trip',
      padBody: false,
      floatingActionButton:
          trip != null && canWrite && online && !trip.isArchived
          ? AddFab(
              label: 'Expense',
              onPressed: () => openTripExpenseSheet(context, trip, names),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tripsProvider),
        child: !online && !async.hasValue
            ? const OnlineOnlyView(feature: 'Trips')
            : async.when(
                loading: () => const LoadingView(),
                error: (e, _) =>
                    ErrorView(e, onRetry: () => ref.invalidate(tripsProvider)),
                data: (t) => t == null
                    ? const EmptyView(
                        icon: Icons.luggage_outlined,
                        title: 'Trip not found',
                        message: 'It may have been deleted on the web.',
                      )
                    : _TripBody(
                        trip: t,
                        names: names,
                        canWrite: canWrite,
                        online: online,
                      ),
              ),
      ),
    );
  }
}

class _TripBody extends StatelessWidget {
  const _TripBody({
    required this.trip,
    required this.names,
    required this.canWrite,
    required this.online,
  });

  final Trip trip;
  final Map<String, String> names;
  final bool canWrite;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final tot = TripTotals.of(trip);
    final over = tot.allocated > 0 && tot.spent > tot.allocated;
    final pct = tot.allocated > 0
        ? (tot.spent / tot.allocated).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.xs,
        AppSpacing.screenGutter,
        96,
      ),
      children: [
        if (!online)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: InlineNote(
              "You're offline — showing the last loaded trip. Adding needs "
              'a connection.',
              warning: true,
              icon: Icons.cloud_off_outlined,
            ),
          ),
        MetricCard(
          eyebrow: '${trip.kindLabel}${trip.isArchived ? ' · Archived' : ''}',
          figure: MoneyFormat.money(tot.spent),
          status: tot.allocated > 0
              ? (over
                    ? 'Over budget by '
                          '${MoneyFormat.money(tot.spent - tot.allocated)}'
                    : '${MoneyFormat.money(tot.remaining)} left of '
                          '${MoneyFormat.money(tot.allocated)}')
              : 'No budget allocated',
          statusColor: over ? finance.expense : palette.muted,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: palette.line,
              color: over ? finance.expense : palette.accent,
            ),
          ),
        ),
        if (trip.allocation.isNotEmpty) ...[
          const SectionTitle('Budget by account'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final e in trip.allocation.entries)
                  ListRow(
                    icon: e.key == kTripCashAccountId
                        ? Icons.payments_outlined
                        : Icons.account_balance_wallet_outlined,
                    title: tripAccountName(e.key, names),
                    subtitle:
                        'Spent ${MoneyFormat.money(tot.spentByAccount[e.key] ?? 0)}'
                        ' of ${MoneyFormat.money(e.value)}',
                    trailing: Text(
                      MoneyFormat.money(tot.remainingByAccount[e.key] ?? 0),
                      style: AppTypography.bodyStrong.copyWith(
                        color: (tot.remainingByAccount[e.key] ?? 0) < 0
                            ? finance.expense
                            : palette.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (trip.companions.isNotEmpty) ...[
          const SectionTitle('Companions'),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              const Chip(
                avatar: Icon(Icons.person, size: 16),
                label: Text(kMe),
              ),
              for (final c in trip.companions)
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(c),
                ),
            ],
          ),
        ],
        TripSettleUpCard(trip: trip, canWrite: canWrite),
        SectionTitle('Expenses (${trip.expenses.length})'),
        if (trip.expenses.isEmpty)
          CardEmpty(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing logged yet',
            message: canWrite
                ? 'Tap Expense to log what this trip costs.'
                : 'Spends logged on this trip show here.',
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final e in trip.expenses)
                  ListRow(
                    icon: _categoryIcon(e.category),
                    title: e.note?.isNotEmpty == true ? e.note! : e.category,
                    titleMaxLines: 2,
                    subtitle: _expenseSubtitle(e),
                    trailing: Text(
                      MoneyFormat.money(e.amount),
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        const InlineNote(
          "Trip spends stay in the trip — they don't count in your "
          'dashboard, budget or net worth.',
          icon: Icons.shield_outlined,
        ),
      ],
    );
  }

  String _expenseSubtitle(TripExpense e) {
    final parts = <String>[
      e.category,
      tripAccountName(e.accountId, names),
      if (e.payer != kMe) 'Paid by ${e.payer}',
      if (e.splitWith?.isNotEmpty == true)
        'Split with ${e.splitWith!.join(', ')}',
    ];
    final at = DateTime.tryParse(e.at)?.toLocal();
    if (at != null) {
      parts.add('${at.day}/${at.month}');
    }
    return parts.join(' · ');
  }
}

IconData _categoryIcon(String c) => switch (c) {
  'Food' => Icons.restaurant_outlined,
  'Stay' => Icons.hotel_outlined,
  'Travel' => Icons.flight_outlined,
  'Activity' => Icons.hiking_outlined,
  'Shopping' => Icons.shopping_bag_outlined,
  _ => Icons.receipt_outlined,
};
