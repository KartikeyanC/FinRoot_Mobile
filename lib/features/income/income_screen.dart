import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../../domain/constants.dart';
import '../accounts/presentation/wealth_kit.dart';
import '../menus/application/menu_providers.dart';
import '../menus/presentation/menu_locked_view.dart';
import '../privacy/income_privacy.dart';
import '../sync/application/sync_engine.dart';
import '../workspace/application/workspace_providers.dart';
import 'domain/income_stream.dart';
import 'income_data.dart';
import 'income_form_sheet.dart';

/// Income streams — the web's Income page on the phone: what comes in a month
/// in rupees (dollar and euro streams converted at their own rate), active
/// against passive, each stream in the order the person keeps it (hold the
/// handle and drag), streams hidden or shown, and add / edit / delete. Every
/// figure respects "Hide income".
class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  /// The order just dragged into, shown until the saved order comes back.
  List<String>? _pending;

  Future<void> _reorder(List<IncomeStream> shown, int from, int to) async {
    // `onReorderItem` already gives the index after the item is removed.
    if (from == to) return;
    final positions = reorderedPositions(shown, from, to);
    final ids = [for (final s in shown) s.id];
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    setState(() => _pending = ids);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(incomeEditorProvider).reorder(positions);
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _openVisibility(List<IncomeStream> all) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _VisibilitySheet(),
      );

  @override
  Widget build(BuildContext context) {
    if (ref.watch(menuStatusProvider(FeatureMenu.income)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: 'Income',
        body: MenuLockedView(feature: 'Income', icon: Icons.payments_outlined),
      );
    }
    final streams = ref.watch(incomeStreamsProvider);
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final hasAny = streams.value?.isNotEmpty ?? false;
    ref.listen(incomeStreamsProvider, (_, _) {
      if (_pending != null) setState(() => _pending = null);
    });

    return AppPage(
      title: 'Income',
      padBody: false,
      actions: [
        const IncomePrivacyButton(),
        if (canWrite && hasAny)
          IconButton(
            key: const ValueKey('income-visibility'),
            tooltip: 'Show or hide streams',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _openVisibility(streams.value ?? const []),
          ),
      ],
      floatingActionButton: canWrite && hasAny
          ? AddFab(
              label: 'Income',
              onPressed: () =>
                  openIncomeForm(context, existing: streams.value ?? const []),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(syncEngineProvider.notifier).syncNow(force: true),
        child: streams.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(e),
          data: (all) {
            if (all.isEmpty) {
              return EmptyView(
                title: 'No income streams',
                message:
                    'Add your salary, rent, dividends or freelance work to see '
                    'what comes in each month, in rupees.',
                icon: Icons.payments_outlined,
                action: canWrite
                    ? FilledButton(
                        key: const ValueKey('income-add-empty'),
                        onPressed: () => openIncomeForm(context, existing: all),
                        child: const Text('Add income'),
                      )
                    : null,
              );
            }
            var shown = shownInOrder(all);
            final pending = _pending;
            if (pending != null) {
              final byId = {for (final s in shown) s.id: s};
              shown = [for (final id in pending) ?byId[id]];
            }
            final hidden = all.length - shown.length;
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenGutter,
                AppSpacing.xs,
                AppSpacing.screenGutter,
                96,
              ),
              buildDefaultDragHandles: false,
              header: _Header(
                summary: IncomeSummary.of(shown),
                hidden: hidden,
                canWrite: canWrite,
                onShowHidden: () => _openVisibility(all),
              ),
              itemCount: shown.length,
              onReorderItem: (from, to) => _reorder(shown, from, to),
              itemBuilder: (context, i) => Padding(
                key: ValueKey(shown[i].id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _StreamCard(
                  stream: shown[i],
                  index: i,
                  canWrite: canWrite,
                  onTap: canWrite
                      ? () => openIncomeForm(
                          context,
                          existing: all,
                          editing: shown[i],
                        )
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.summary,
    required this.hidden,
    required this.canWrite,
    required this.onShowHidden,
  });

  final IncomeSummary summary;
  final int hidden;
  final bool canWrite;
  final VoidCallback onShowHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    String money(double v) => incomeText(ref, MoneyFormat.short(v));
    final parts = [
      'Active ${money(summary.active)}',
      'Passive ${money(summary.passive)}',
      if (summary.oneTime > 0) 'One-time ${money(summary.oneTime)}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricCard(
          key: const ValueKey('income-summary'),
          eyebrow: 'Income a month',
          figure: money(summary.monthly),
          figureSuffix:
              'from ${summary.count} ${summary.count == 1 ? 'stream' : 'streams'}',
          status: [
            parts.join(' · '),
            if (summary.foreign > 0)
              '${summary.foreign} in another currency, shown in rupees',
          ].join('\n'),
          statusColor: palette.muted,
        ),
        SectionTitle(
          'Streams',
          trailing: hidden > 0
              ? TextButton(
                  onPressed: canWrite ? onShowHidden : null,
                  child: Text('$hidden hidden'),
                )
              : canWrite && summary.count > 1
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Drag',
                      style: AppTypography.label.copyWith(color: palette.muted),
                    ),
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: palette.muted,
                    ),
                    Text(
                      'to reorder',
                      style: AppTypography.label.copyWith(color: palette.muted),
                    ),
                  ],
                )
              : null,
        ),
        if (summary.count == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Every stream is hidden. Tap "$hidden hidden" to show some.',
              style: AppTypography.body.copyWith(color: palette.muted),
            ),
          ),
      ],
    );
  }
}

class _StreamCard extends ConsumerWidget {
  const _StreamCard({
    required this.stream,
    required this.index,
    required this.canWrite,
    this.onTap,
  });

  final IncomeStream stream;
  final int index;
  final bool canWrite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final s = stream;
    final tone = s.isActive ? Tones.mint(context) : Tones.sky(context);
    final rate = s.rate == s.rate.roundToDouble()
        ? s.rate.toInt().toString()
        : s.rate.toString();
    final own =
        '${MoneyFormat.money(s.amount, currency: s.currency)} at ₹$rate';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          ToneTile(icon: incomeIcon(s.icon), tone: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${s.isActive ? 'Active' : 'Passive'} · ${s.frequencyLabel}',
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
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                incomeText(ref, MoneyFormat.money(s.inr)),
                key: ValueKey('income-inr-${s.id}'),
                style: AppTypography.bodyStrong.copyWith(
                  color: context.finance.income,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (s.isForeign)
                Text(
                  incomeText(ref, own),
                  style: AppTypography.label.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          if (canWrite)
            ReorderableDragStartListener(
              index: index,
              child: Semantics(
                label: 'Drag to reorder ${s.name}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.md,
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: palette.faint,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Every stream with a switch: shown on the page and in the totals, or not
/// (the web's "Manage categories" sheet).
class _VisibilitySheet extends ConsumerWidget {
  const _VisibilitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final all = ref.watch(incomeStreamsProvider).value ?? const [];
    Future<void> toggle(IncomeStream s, bool v) async {
      try {
        await ref.read(incomeEditorProvider).setVisible(s, visible: v);
      } on Failure catch (f) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(f.message)));
        }
      }
    }

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Show or hide streams',
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Hidden streams stay saved but leave the list and the totals.',
            style: AppTypography.body.copyWith(color: palette.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final s in all)
            SwitchListTile(
              key: ValueKey('income-visible-${s.id}'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(incomeIcon(s.icon), color: palette.muted),
              title: Text(s.name),
              subtitle: Text(s.isActive ? 'Active' : 'Passive'),
              value: s.visible,
              onChanged: (v) => toggle(s, v),
            ),
        ],
      ),
    );
  }
}
