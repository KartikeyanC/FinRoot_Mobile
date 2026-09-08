import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../design/design.dart';

/// Home — the mobile financial feed. M6 builds the real thing (snapshot, quick
/// actions, recent activity, trackers, upcoming, insights). M2 only proves the
/// shell + design system render.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final greeting = _greeting();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenGutter,
          ),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text(greeting, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              user?.email ?? 'Welcome',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const AmountText(0, size: AmountSize.hero, signed: false),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Balances appear once accounts sync (M8).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SectionHeader('Recent'),
            const EmptyView(
              title: 'No transactions yet',
              message: 'Tap + to record your first expense.',
              icon: Icons.receipt_long_outlined,
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
