import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design/design.dart';
import '../../../navigation/destinations.dart';

/// "More" — secondary features via progressive disclosure (brief §5). Menu
/// gating (`get_effective_menus`) is wired in M3; today every entry shows.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        itemCount: kMoreEntries.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
        itemBuilder: (context, i) {
          final e = kMoreEntries[i];
          return ListTile(
            leading: Icon(e.icon),
            title: Text(e.label),
            trailing: e.phase == null
                ? const Icon(Icons.chevron_right)
                : Text(
                    e.phase!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
            onTap: () => context.push(e.route),
          );
        },
      ),
    );
  }
}
