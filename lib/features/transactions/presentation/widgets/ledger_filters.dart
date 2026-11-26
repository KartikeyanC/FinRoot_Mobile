import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design/design.dart';
import '../../application/transactions_providers.dart';
import '../../domain/ledger_range.dart';

/// The ledger's date and category filters: two buttons that open pickers,
/// then the active choices as removable chips with a Clear.
class LedgerFilterBar extends ConsumerWidget {
  const LedgerFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(ledgerFilterProvider);
    final notifier = ref.read(ledgerFilterProvider.notifier);
    final cats = filter.categories;
    final catLabel = switch (cats.length) {
      0 => 'Any category',
      1 => cats.first,
      _ => '${cats.length} categories',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _FilterButton(
                icon: Icons.calendar_month_rounded,
                label: filter.range?.label ?? 'Any date',
                on: filter.range != null,
                tooltip: 'Filter by date',
                onTap: () => pickLedgerRange(context, ref),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _FilterButton(
                icon: Icons.category_outlined,
                label: catLabel,
                on: cats.isNotEmpty,
                tooltip: 'Filter by category',
                onTap: () => pickLedgerCategories(context, ref),
              ),
            ),
          ],
        ),
        if (filter.hasRangeOrCategory) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (filter.range != null)
                InputChip(
                  key: const ValueKey('ledger-range-chip'),
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(filter.range!.label),
                  onDeleted: () => notifier.setRange(null),
                  deleteButtonTooltipMessage: 'Remove date filter',
                ),
              for (final c in cats)
                InputChip(
                  key: ValueKey('ledger-category-chip-$c'),
                  label: Text(c),
                  onDeleted: () => notifier.removeCategory(c),
                  deleteButtonTooltipMessage: 'Remove $c',
                ),
              TextButton(
                onPressed: () {
                  notifier.setRange(null);
                  notifier.setCategories(const {});
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.on,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool on;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fg = on ? palette.accent : palette.ink;
    return Semantics(
      button: true,
      label: '$tooltip: $label',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: StadiumBorder(
          side: BorderSide(color: on ? palette.accent : palette.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: on ? palette.accent : palette.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyStrong.copyWith(color: fg),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 18, color: palette.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Picked "All dates" in the range sheet (null means the sheet was dismissed).
const _anyDate = Object();

/// Ask for a date range (presets, Custom via the date-range picker, or All)
/// and apply it to the ledger.
Future<void> pickLedgerRange(BuildContext context, WidgetRef ref) async {
  final current = ref.read(ledgerFilterProvider).range;
  final choice = await showModalBottomSheet<Object>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.sm,
            ),
            child: Text('Date', style: AppTypography.title),
          ),
          _RangeTile(
            label: 'All dates',
            on: current == null,
            onTap: () => Navigator.pop(context, _anyDate),
          ),
          for (final p in LedgerRangePreset.values)
            _RangeTile(
              label: p == LedgerRangePreset.custom ? 'Custom…' : p.label,
              on: current?.preset == p,
              onTap: () => Navigator.pop(context, p),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  final notifier = ref.read(ledgerFilterProvider.notifier);
  if (identical(choice, _anyDate)) {
    notifier.setRange(null);
    return;
  }
  final preset = choice as LedgerRangePreset;
  final now = DateTime.now();
  if (preset != LedgerRangePreset.custom) {
    notifier.setRange(LedgerRange.preset(preset, now));
    return;
  }
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 1, 12, 31),
    initialDateRange: current == null
        ? null
        : DateTimeRange(start: current.from, end: current.lastDay),
    helpText: 'Show transactions between',
  );
  if (picked == null) return;
  notifier.setRange(LedgerRange.custom(picked.start, picked.end));
}

class _RangeTile extends StatelessWidget {
  const _RangeTile({
    required this.label,
    required this.on,
    required this.onTap,
  });
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      title: Text(label, style: AppTypography.bodyStrong),
      trailing: on ? Icon(Icons.check_rounded, color: palette.accent) : null,
      onTap: onTap,
    );
  }
}

/// Ask which categories to show (one or several) and apply them.
Future<void> pickLedgerCategories(BuildContext context, WidgetRef ref) async {
  final current = ref.read(ledgerFilterProvider).categories;
  final picked = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CategorySheet(initial: current),
  );
  if (picked == null) return;
  ref.read(ledgerFilterProvider.notifier).setCategories(picked);
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({required this.initial});
  final Set<String> initial;

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final known = ref.watch(ledgerCategoriesProvider);
    final options = <String>{...?known.value, ...widget.initial}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Categories', style: AppTypography.title)),
                if (_picked.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_picked.clear),
                    child: const Text('Any category'),
                  ),
              ],
            ),
          ),
          Flexible(
            child: known.isLoading && options.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : options.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Text(
                      'No categories on the phone yet.',
                      style: AppTypography.body.copyWith(color: palette.muted),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final c in options)
                        CheckboxListTile(
                          value: _picked.contains(c),
                          title: Text(c, style: AppTypography.bodyStrong),
                          activeColor: palette.accent,
                          onChanged: (v) => setState(() {
                            if (v ?? false) {
                              _picked.add(c);
                            } else {
                              _picked.remove(c);
                            }
                          }),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: PillButton(
              label: _picked.isEmpty
                  ? 'Show every category'
                  : 'Show ${_picked.length == 1 ? '1 category' : '${_picked.length} categories'}',
              expand: true,
              onPressed: () => Navigator.pop(context, {..._picked}),
            ),
          ),
        ],
      ),
    );
  }
}

/// Said in the list when the chosen range reaches past what the phone holds.
class LedgerCacheNotice extends StatelessWidget {
  const LedgerCacheNotice({super.key});

  static const message =
      'Older than 180 days isn\'t on the phone — use Export or the web app '
      'to see it.';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: AppRadius.tile,
        border: Border.all(color: palette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 18,
              color: palette.muted,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body.copyWith(color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
