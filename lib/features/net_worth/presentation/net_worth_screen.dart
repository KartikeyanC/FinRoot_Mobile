import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/time/relative_time.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/net_worth_editor_controller.dart';
import '../application/net_worth_providers.dart';
import '../domain/net_worth.dart';
import 'entry_form_sheet.dart';

/// Net worth (M11) — a manual asset / liability ledger; net worth is assets
/// minus liabilities (web `netWorthStore.ts` — it does not auto-compose from
/// accounts or investments). Menu-gated. Online-only (not cached).
class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.netWorth)) ==
        MenuStatus.locked;
    if (locked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Net worth')),
        body: const MenuLockedView(
          feature: 'Net worth',
          icon: Icons.balance_outlined,
        ),
      );
    }

    final entries = ref.watch(netWorthEntriesProvider);
    final totals = ref.watch(netWorthTotalsProvider);
    final history = ref.watch(netWorthHistoryProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => openNetWorthEntryForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(netWorthEntriesProvider);
          ref.invalidate(netWorthHistoryProvider);
        },
        child: entries.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
            e,
            onRetry: () => ref.invalidate(netWorthEntriesProvider),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.huge,
            ),
            children: [
              _HeadlineCard(totals: totals),
              _TrendLine(history: history.value ?? const []),
              if (list.isEmpty)
                _Empty(canWrite: canWrite)
              else ...[
                _GroupSection(
                  title: 'Assets',
                  entries: list.where((e) => e.isAsset).toList(),
                  canWrite: canWrite,
                ),
                _GroupSection(
                  title: 'Liabilities',
                  entries: list.where((e) => !e.isAsset).toList(),
                  canWrite: canWrite,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.totals});
  final NetWorthTotals totals;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Net worth',
            style: tt.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xxs),
          AmountText.money(totals.netWorth, size: AmountSize.hero),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Assets ${totals.assets.formatShort()}',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                'Liabilities ${totals.liabilities.formatShort()}',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.history});
  final List<NetWorthPoint> history;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();
    final first = history.first.netWorth;
    final last = history.last.netWorth;
    final delta = last - first;
    final up = delta.amount.sign >= 0;
    final finance = context.finance;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.xs),
      child: Text(
        '${up ? '▲' : '▼'} ${delta.abs.formatShort()} since '
        '${RelativeTime.dayLabel(history.first.capturedOn)} '
        '(${history.length} snapshots)',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: up ? finance.income : finance.expense,
        ),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.entries,
    required this.canWrite,
  });

  final String title;
  final List<NetWorthEntry> entries;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _EntryRow(entry: entries[i], canWrite: canWrite),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry, required this.canWrite});
  final NetWorthEntry entry;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: canWrite
          ? () => openNetWorthEntryForm(context, editing: entry)
          : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSpacing.minTouchTarget,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyLarge,
                    ),
                    Text(
                      groupLabel(entry.group),
                      style: tt.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AmountText.money(entry.amount, signed: false),
              if (canWrite)
                IconButton(
                  tooltip: 'Delete entry',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await ref
                          .read(netWorthEditorControllerProvider)
                          .delete(entry.id);
                    } on Failure catch (f) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(f.message)),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canWrite});
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: EmptyView(
        icon: Icons.balance_outlined,
        title: 'Build the picture',
        message:
            'Add what you own and what you owe — the difference is your net '
            'worth, and the app tracks it over time.',
        action: canWrite
            ? FilledButton(
                onPressed: () => openNetWorthEntryForm(context),
                child: const Text('Add an item'),
              )
            : null,
      ),
    );
  }
}
