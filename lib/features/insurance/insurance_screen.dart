import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/error_mapper.dart';
import '../../core/money/money_format.dart';
import '../../core/providers/providers.dart';
import '../../data/local/cached_rows.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
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

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(menuStatusProvider(FeatureMenu.insurance)) == MenuStatus.locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Insurance')),
        body: const MenuLockedView(feature: 'Insurance', icon: Icons.health_and_safety_outlined),
      );
    }
    final policies = ref.watch(insuranceProvider);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Insurance')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: policies.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: AppSpacing.huge),
                EmptyView(
                  title: 'No policies',
                  message: 'Policies you add on the web dashboard show up here.',
                  icon: Icons.health_and_safety_outlined,
                ),
              ]);
            }
            final cover = list.fold<double>(0, (s, p) => s + p.sumInsured);
            final premiums = list.fold<double>(0, (s, p) => s + p.premium);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter, AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.huge,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total cover', style: tt.labelMedium),
                      Text(MoneyFormat.money(cover), style: tt.headlineSmall),
                      Text('${list.length} policies · ${MoneyFormat.money(premiums)} in premiums',
                          style: tt.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final p in list) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: tt.titleMedium),
                        Text(
                          [p.category, if (p.provider?.isNotEmpty == true) p.provider!].join(' · '),
                          style: tt.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Cover ${MoneyFormat.money(p.sumInsured)} · '
                            'premium ${MoneyFormat.money(p.premium)}'
                            '${p.frequency?.isNotEmpty == true ? ' (${p.frequency})' : ''}'),
                        if (p.due != null)
                          Text(
                            'Due ${_date.format(p.due!)}',
                            style: tt.bodyMedium?.copyWith(
                              color: p.due!.difference(DateTime.now()).inDays <= 15 ? scheme.error : null,
                            ),
                          ),
                        if (p.policyNumber?.isNotEmpty == true)
                          Text('Policy no. ${p.policyNumber}', style: tt.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
