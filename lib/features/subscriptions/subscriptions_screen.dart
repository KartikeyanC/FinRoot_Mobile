import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
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
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscriptions')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: subs.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: AppSpacing.huge),
                EmptyView(
                  title: 'No subscriptions',
                  message: 'Subscriptions you track on the web dashboard show up here.',
                  icon: Icons.subscriptions_outlined,
                ),
              ]);
            }
            final active = list.where((s) => s.active).toList()
              ..sort((a, b) => (a.renewal ?? DateTime(9999)).compareTo(b.renewal ?? DateTime(9999)));
            final cancelled = list.where((s) => !s.active).toList();
            final perMonth = active.fold<double>(0, (s, x) => s + x.perMonth);

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter, AppSpacing.lg, AppSpacing.screenGutter, AppSpacing.huge,
              ),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active subscriptions cost', style: tt.labelMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text('${MoneyFormat.money(perMonth)} a month', style: tt.headlineSmall),
                      Text('${MoneyFormat.money(perMonth * 12)} a year · ${active.length} active',
                          style: tt.bodySmall),
                    ],
                  ),
                ),
                if (active.isNotEmpty) const SectionHeader('Active'),
                for (final s in active) _SubTile(s, canWrite: canWrite),
                if (cancelled.isNotEmpty) const SectionHeader('Cancelled'),
                for (final s in cancelled) _SubTile(s, canWrite: canWrite),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubTile extends ConsumerWidget {
  const _SubTile(this.sub, {required this.canWrite});
  final TrackedSubscription sub;
  final bool canWrite;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await setSubscriptionActive(ref, sub, active: !sub.active);
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final soon = sub.active &&
        sub.renewal != null &&
        sub.renewal!.difference(DateTime.now()).inDays <= 3;
    final parts = [
      '${MoneyFormat.money(sub.amount, currency: sub.currency)} / ${sub.frequencyLabel}',
      if (sub.renewal != null) 'renews ${_date.format(sub.renewal!)}',
      if (sub.category != null && sub.category!.isNotEmpty) sub.category!,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        child: Text(sub.icon?.isNotEmpty == true ? sub.icon! : sub.name.characters.first),
      ),
      title: Text(sub.name),
      subtitle: Text(parts.join(' · '), style: soon ? TextStyle(color: scheme.error) : null),
      trailing: canWrite
          ? TextButton(
              onPressed: () => _toggle(context, ref),
              child: Text(sub.active ? 'Cancel' : 'Resume'),
            )
          : null,
    );
  }
}
