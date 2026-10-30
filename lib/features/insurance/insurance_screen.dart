import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/error_mapper.dart';
import '../../core/money/money_format.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
import '../accounts/presentation/wealth_kit.dart';
import '../menus/application/menu_providers.dart';
import '../menus/presentation/menu_locked_view.dart';
import '../sync/application/sync_engine.dart';

/// A policy from the web's Insurance page (`insurance` table). View-only on the
/// phone; documents and edits stay on the web.
class InsurancePolicy {
  const InsurancePolicy({
    required this.id,
    required this.name,
    required this.category,
    required this.premium,
    required this.sumInsured,
    this.provider,
    this.policyNumber,
    this.frequency,
    this.due,
    this.notes,
  });

  factory InsurancePolicy.fromRow(Map<String, dynamic> r) => InsurancePolicy(
        id: r['id'] as String,
        name: (r['policy_name'] as String?) ?? 'Policy',
        category: (r['category'] as String?) ?? '',
        premium: asDouble(r['premium']),
        sumInsured: asDouble(r['sum_insured']),
        provider: r['provider'] as String?,
        policyNumber: r['policy_number'] as String?,
        frequency: r['payment_frequency'] as String?,
        due: asDate(r['due_date']),
        notes: r['notes'] as String?,
      );

  final String id;
  final String name;
  final String category;
  final double premium;
  final double sumInsured;
  final String? provider;
  final String? policyNumber;
  final String? frequency;
  final DateTime? due;
  final String? notes;
}

final insuranceProvider = FutureProvider<List<InsurancePolicy>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await watchCachedRows(ref, 'insurance', (tenantId) async {
    try {
      // Not the inline document (document_data_url can be megabytes).
      final rows = await client
          .from('insurance')
          .select('id, policy_name, category, premium, sum_insured, provider, '
              'policy_number, payment_frequency, due_date, notes')
          .eq('tenant_id', tenantId)
          .order('due_date', ascending: true, nullsFirst: false);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  });
  return [for (final r in rows) InsurancePolicy.fromRow(r)];
}, name: 'insurance');

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

    return AppPage(
      title: 'Insurance',
      padBody: false,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: policies.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyView(
                title: 'No policies',
                message:
                    'Policies you add on the web dashboard show up here, with '
                    'their cover and the next premium due.',
                icon: Icons.health_and_safety_outlined,
              );
            }
            final cover = list.fold<double>(0, (s, p) => s + p.sumInsured);
            final premiums = list.fold<double>(0, (s, p) => s + p.premium);
            final dueSoon = list
                .where(
                  (p) =>
                      p.due != null &&
                      p.due!.difference(DateTime.now()).inDays <= 15,
                )
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                AppSpacing.huge,
              ),
              children: [
                MetricCard(
                  eyebrow: 'Total cover',
                  figure: MoneyFormat.short(cover),
                  figureSuffix:
                      '${list.length} ${list.length == 1 ? 'policy' : 'policies'}',
                  status: dueSoon > 0
                      ? '$dueSoon premium${dueSoon == 1 ? '' : 's'} due soon'
                      : '${MoneyFormat.money(premiums)} in premiums',
                  statusColor: dueSoon > 0
                      ? context.finance.expense
                      : context.palette.muted,
                ),
                const SectionTitle('Policies'),
                for (var i = 0; i < list.length; i++) ...[
                  _PolicyCard(list[i], index: i),
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
  const _PolicyCard(this.p, {required this.index});
  final InsurancePolicy p;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final days = p.due?.difference(DateTime.now()).inDays;
    final soon = days != null && days <= 15;
    final Widget? duePill = p.due == null
        ? null
        : TonePill(
            'Due ${_date.format(p.due!)}',
            soon ? Tones.coral(context) : Tones.mint(context),
          );
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      [
                        p.category,
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
          if (duePill != null || p.policyNumber?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ?duePill,
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
