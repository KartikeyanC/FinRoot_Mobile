import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../accounts/presentation/wealth_kit.dart';
import '../sync/application/sync_engine.dart';
import '../workspace/application/workspace_providers.dart';
import 'subscriptions.dart';

final _date = DateFormat('d MMM yyyy');

/// Subscriptions — the web dashboard's page on the phone: what you pay a
/// month for active ones, the next renewal, and cancel / resume tracking.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subs = ref.watch(trackedSubscriptionsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;

    return AppPage(
      title: 'Subscriptions',
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: subs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyView(
                title: 'No subscriptions',
                message:
                    'Subscriptions you track on the web dashboard show up '
                    'here, with what they cost and when they renew.',
                icon: Icons.subscriptions_outlined,
              );
            }
            final active = list.where((s) => s.active).toList()
              ..sort(
                (a, b) => (a.renewal ?? DateTime(9999)).compareTo(
                  b.renewal ?? DateTime(9999),
                ),
              );
            final cancelled = list.where((s) => !s.active).toList();
            final perMonth = active.fold<double>(0, (s, x) => s + x.perMonth);

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                MetricCard(
                  eyebrow: 'Active subscriptions cost',
                  figure: MoneyFormat.money(perMonth),
                  figureSuffix: 'a month',
                  status:
                      '${MoneyFormat.money(perMonth * 12)} a year · '
                      '${active.length} active',
                  statusColor: context.palette.muted,
                ),
                if (active.isNotEmpty) const SectionTitle('Active'),
                for (var i = 0; i < active.length; i++)
                  _SubTile(active[i], index: i, canWrite: canWrite),
                if (cancelled.isNotEmpty) const SectionTitle('Cancelled'),
                for (var i = 0; i < cancelled.length; i++)
                  _SubTile(cancelled[i], index: i, canWrite: canWrite),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubTile extends ConsumerWidget {
  const _SubTile(this.sub, {required this.index, required this.canWrite});
  final TrackedSubscription sub;
  final int index;
  final bool canWrite;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await setSubscriptionActive(ref, sub, active: !sub.active);
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final days = sub.renewal?.difference(DateTime.now()).inDays;
    final soon = sub.active && days != null && days <= 3;
    final tone = sub.active ? Tones.byIndex(context, index) : Tones.accent(context);
    final glyph = sub.icon?.isNotEmpty == true
        ? sub.icon!
        : sub.name.characters.first.toUpperCase();
    final parts = [
      if (sub.renewal != null) 'renews ${_date.format(sub.renewal!)}',
      if (sub.category != null && sub.category!.isNotEmpty) sub.category!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sub.active ? tone.bg : palette.subtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                glyph,
                style: AppTypography.bodyStrong.copyWith(
                  color: tone.fg,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(
                      color: sub.active ? palette.ink : palette.muted,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${MoneyFormat.money(sub.amount, currency: sub.currency)} / ${sub.frequencyLabel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (parts.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: soon
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: TonePill(
                                  days < 0
                                      ? 'Renewal passed'
                                      : (days == 0
                                            ? 'Renews today'
                                            : 'Renews in $days ${days == 1 ? 'day' : 'days'}'),
                                  Tones.coral(context),
                                ),
                              ),
                            )
                          : Text(
                              parts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.label.copyWith(
                                color: palette.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                ],
              ),
            ),
            if (canWrite) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _toggle(context, ref),
                child: Text(sub.active ? 'Cancel' : 'Resume'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
