import 'package:flutter/material.dart';

import '../../../../design/design.dart';

/// Feed sections whose data source lands in a later phase. Shown as quiet,
/// honest "coming in M…" cards rather than hidden — the feed's shape is part of
/// the mobile design language (brief), and a person should see what's planned.
class HomeUpcomingCard extends StatelessWidget {
  const HomeUpcomingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoonCard(
      icon: Icons.event_repeat_outlined,
      title: 'Upcoming',
      body: 'Recurring items and reminders show up here in M12.',
    );
  }
}

class HomeInsightsCard extends StatelessWidget {
  const HomeInsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoonCard(
      icon: Icons.auto_awesome_outlined,
      title: 'Insights',
      body: 'Spending patterns and nudges arrive with AI Insights in M15.',
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
