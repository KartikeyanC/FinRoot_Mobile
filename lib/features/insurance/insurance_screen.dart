import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
import '../accounts/presentation/wealth_kit.dart';
import '../menus/application/menu_providers.dart';
import '../menus/presentation/menu_locked_view.dart';
import '../sync/application/sync_engine.dart';
import '../workspace/application/workspace_providers.dart';
import 'insurance.dart';
import 'insurance_form_sheet.dart';

final _date = DateFormat('d MMM yyyy');

IconData _iconFor(String category) {
  final c = category.toLowerCase();
  if (c.contains('health') || c.contains('medical')) {
    return Icons.health_and_safety_outlined;
  }
  if (c.contains('life') || c.contains('term')) return Icons.favorite_border;
  if (c.contains('vehicle') || c.contains('car') || c.contains('motor')) {
    return Icons.directions_car_outlined;
  }
  if (c.contains('home') || c.contains('property')) return Icons.home_outlined;
  if (c.contains('travel')) return Icons.flight_takeoff_rounded;
  return Icons.verified_user_outlined;
}

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(menuStatusProvider(FeatureMenu.insurance)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: 'Insurance',
        body: MenuLockedView(
          feature: 'Insurance',
          icon: Icons.health_and_safety_outlined,
        ),
      );
    }
    final policies = ref.watch(insuranceProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final hasAny = policies.value?.isNotEmpty ?? false;

    return AppPage(
      title: 'Insurance',
      padBody: false,
      floatingActionButton: canWrite && hasAny
          ? AddFab(label: 'Policy', onPressed: () => openPolicyForm(context))
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: policies.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return EmptyView(
                title: 'No policies',
                message:
                    'Add your health, life, vehicle or gadget cover to see '
                    'the total cover and when each premium is due.',
                icon: Icons.health_and_safety_outlined,
                action: canWrite
                    ? FilledButton(
                        key: const ValueKey('policy-add-empty'),
                        onPressed: () => openPolicyForm(context),
                        child: const Text('Add a policy'),
                      )
                    : null,
              );
            }
            final cover = list.fold<double>(0, (s, p) => s + p.sumInsured);
            // A year's worth, as the web counts it (one-time premiums aside).
            final premiums = list.fold<double>(
              0,
              (s, p) => s + p.yearlyPremium,
            );
            final today = DateTime.now();
            final dueSoon = list
                .where((p) => PremiumDisplay.of(p, today).dueSoon)
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                96,
              ),
              children: [
                MetricCard(
                  eyebrow: 'Total cover',
                  figure: MoneyFormat.short(cover),
                  figureSuffix:
                      '${list.length} ${list.length == 1 ? 'policy' : 'policies'}',
                  status: dueSoon > 0
                      ? '$dueSoon premium${dueSoon == 1 ? '' : 's'} due soon'
                      : '${MoneyFormat.money(premiums)} a year in premiums',
                  statusColor: dueSoon > 0
                      ? context.finance.expense
                      : context.palette.muted,
                ),
                const SectionTitle('Policies'),
                for (var i = 0; i < list.length; i++) ...[
                  _PolicyCard(list[i], index: i, canWrite: canWrite),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard(this.p, {required this.index, required this.canWrite});
  final InsurancePolicy p;
  final int index;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final premium = PremiumDisplay.of(p, DateTime.now());
    final Widget? duePill = premium.next != null
        ? TonePill(
            premium.daysAway == 0
                ? 'Due today'
                : 'Next premium ${_date.format(premium.next!)}',
            premium.dueSoon ? Tones.coral(context) : Tones.mint(context),
          )
        : premium.ended
        ? TonePill('Paid · one-time', Tones.mint(context))
        : null;
    Widget fact(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong.copyWith(color: palette.ink),
          ),
        ],
      ),
    );

    return AppCard(
      onTap: canWrite ? () => openPolicyForm(context, editing: p) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ToneTile(
                icon: _iconFor(p.category),
                tone: Tones.byIndex(context, index),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      key: ValueKey('policy-${p.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      [
                        p.categoryLabel,
                        if (p.provider?.isNotEmpty == true) p.provider!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              fact('Cover', MoneyFormat.money(p.sumInsured)),
              fact(
                p.frequency?.isNotEmpty == true
                    ? 'Premium (${p.frequency})'
                    : 'Premium',
                MoneyFormat.money(p.premium),
              ),
            ],
          ),
          if (duePill != null ||
              p.policyNumber?.isNotEmpty == true ||
              p.documentPath != null ||
              p.hasLegacyDocument) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ?duePill,
                if (p.documentPath != null || p.hasLegacyDocument)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 16,
                        color: palette.muted,
                      ),
                      Text(
                        'Document',
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (p.policyNumber?.isNotEmpty == true)
                  Text(
                    'Policy no. ${p.policyNumber}',
                    style: AppTypography.label.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
