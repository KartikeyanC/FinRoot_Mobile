import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/widgets/date_time_field.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../application/bill_scan_controller.dart';
import '../domain/scanned_row.dart';
import 'row_edit_sheet.dart';

/// Bill scan (M13) — photograph a receipt, the shared `scan-receipt` Edge
/// Function (Gemini vision) extracts it, you review, and it logs as one
/// expense through the normal Quick Add write path. `bill-scan` is a
/// navigation-only menu (web `menuContract`): the gate here hides the screen,
/// the Edge Function does its own membership check.
class BillScanScreen extends ConsumerWidget {
  const BillScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked =
        ref.watch(menuStatusProvider(FeatureMenu.billScan)) ==
        MenuStatus.locked;
    if (locked) {
      return const Scaffold(
        body: MenuLockedView(
          feature: 'Bill scan',
          icon: Icons.document_scanner_outlined,
        ),
      );
    }

    final state = ref.watch(billScanControllerProvider);
    final c = ref.read(billScanControllerProvider.notifier);

    return AppPage(
      title: 'Bill scan',
      subtitle: 'Photograph a receipt, review, log',
      actions: [
        if (state.images.isNotEmpty || state.result != null)
          TextButton(onPressed: c.reset, child: const Text('Start over')),
      ],
      padBody: false,
      body: switch (state.phase) {
        BillScanPhase.scanning => const _Scanning(),
        BillScanPhase.review => _Review(state: state),
        BillScanPhase.staging => _Staging(state: state),
      },
    );
  }
}

// --------------------------------------------------------------------------
// Staging
// --------------------------------------------------------------------------

class _Staging extends ConsumerWidget {
  const _Staging({required this.state});
  final BillScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billScanControllerProvider.notifier);
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenGutter,
        AppSpacing.lg,
        AppSpacing.screenGutter,
        AppSpacing.huge,
      ),
      children: [
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: Icons.document_scanner_rounded),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Photograph a receipt — a long bill shot in a few parts '
                  'works too. AI pulls out the merchant, items and total; you '
                  'review before it is logged.',
                  style: AppTypography.body.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: c.captureFromCamera,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: c.addFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
        if (state.rejected.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final r in state.rejected)
            Text(
              '• ${r.reason}',
              style: tt.bodySmall?.copyWith(color: scheme.error),
            ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorNote(state.error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (state.images.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm),
            child: CardEmpty(
              icon: Icons.receipt_long_rounded,
              title: 'No photo yet',
              message: 'Add up to 5 photos of one receipt.',
            ),
          )
        else ...[
          SectionTitle('${state.images.length} of 5 photos'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final img in state.images)
                _Thumb(
                  key: ValueKey<String>(img.id),
                  bytes: img.bytes,
                  onRemove: () => c.removeImage(img.id),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: state.canScan ? c.scan : null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Scan receipt'),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({super.key, required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: AppRadius.field,
          child: Image.memory(
            bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            semanticLabel: 'Receipt photo',
            errorBuilder: (_, _, _) => Container(
              width: 96,
              height: 96,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: RoundIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Remove photo',
            size: 28,
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Scanning
// --------------------------------------------------------------------------

class _Scanning extends StatelessWidget {
  const _Scanning();

  @override
  Widget build(BuildContext context) {
    return const LoadingView(label: 'Reading the receipt…');
  }
}

// --------------------------------------------------------------------------
// Review
// --------------------------------------------------------------------------

class _Review extends ConsumerWidget {
  const _Review({required this.state});
  final BillScanState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(billScanControllerProvider.notifier);
    final result = state.result!;
    final parts = partitionRows(state.rows);
    final approval = state.approval;
    final planned = state.planned;
    final recon = state.reconciliation;
    var plannedTotal = Money.zero(
      approval?.amount.currency ?? result.total.currency,
    );
    for (final p in planned) {
      plannedTotal = plannedTotal + p.amount;
    }
    final categories = {for (final r in state.rows) r.category}.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenGutter,
              AppSpacing.lg,
              AppSpacing.screenGutter,
              AppSpacing.xxl,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
                child: Text(
                  result.merchant.isEmpty ? 'Receipt' : result.merchant,
                  style: AppTypography.title.copyWith(
                    color: context.palette.ink,
                  ),
                ),
              ),
              MetricCard(
                eyebrow: 'Receipt total',
                figure: approval == null ? '—' : approval.amount.format(),
                figureSuffix: result.date == null
                    ? null
                    : '${result.date!.day}/${result.date!.month}/${result.date!.year}',
                status:
                    '${parts.items.length} '
                    '${parts.items.length == 1 ? 'item' : 'items'} to review',
              ),
              const SizedBox(height: AppSpacing.md),
              DateTimeField(
                value: approval?.date,
                lastDate: DateTime.now(),
                onChanged: c.setDateTime,
              ),
              const SizedBox(height: AppSpacing.md),
              FilterPills<ScanMode>(
                options: const [
                  FilterPill(ScanMode.lumpsum, 'Whole bill'),
                  FilterPill(ScanMode.lineItem, 'Line items'),
                ],
                selected: state.mode,
                onSelected: c.setMode,
              ),
              const SizedBox(height: AppSpacing.md),
              _SplitOptions(
                state: state,
                categories: categories,
                onSaveMode: c.setSaveMode,
                onPeople: c.setPeople,
              ),
              const SizedBox(height: AppSpacing.md),
              if (recon != null && !recon.matches) _ReconWarning(recon: recon),
              for (final row in parts.items)
                _ItemCard(
                  row: row,
                  onEdit: () => openRowEditSheet(context, ref, row),
                  onRemove: () => c.removeRow(row.id),
                ),
              if (parts.taxes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _TaxStrip(rows: parts.taxes, onRemove: c.removeRow),
              ],
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ErrorNote(state.error!),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              key: const ValueKey('bill-approve'),
              onPressed:
                  planned.isNotEmpty &&
                      planned.every((p) => p.amount.isPositive)
                  ? () => _approve(context, ref)
                  : null,
              child: Text(
                planned.isEmpty
                    ? 'Nothing to log'
                    : planned.length > 1
                    ? 'Log ${planned.length} expenses · '
                          '${plannedTotal.format()}'
                    : state.people > 1
                    ? 'Log your share · ${plannedTotal.format()}'
                    : 'Log expense · ${plannedTotal.format()}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = ref.read(billScanControllerProvider).planned.length;
    try {
      await ref.read(billScanControllerProvider.notifier).approve();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count > 1
                ? '$count expenses logged, one per category'
                : 'Logged to your expenses',
          ),
        ),
      );
    } on Failure catch (f) {
      messenger.showSnackBar(SnackBar(content: Text(f.message)));
    }
  }
}

/// The split options: one expense or one per category (line items with
/// more than one category), and how many people share the bill.
class _SplitOptions extends StatelessWidget {
  const _SplitOptions({
    required this.state,
    required this.categories,
    required this.onSaveMode,
    required this.onPeople,
  });
  final BillScanState state;
  final int categories;
  final ValueChanged<BillSaveMode> onSaveMode;
  final ValueChanged<int> onPeople;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final byCategory = state.mode == ScanMode.lineItem && categories > 1;
    final people = state.people;
    return AppCard(
      key: const ValueKey('bill-split'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Split',
            style: AppTypography.bodyStrong.copyWith(color: palette.ink),
          ),
          if (byCategory) ...[
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<BillSaveMode>(
              key: const ValueKey('bill-save-mode'),
              segments: [
                const ButtonSegment(
                  value: BillSaveMode.single,
                  label: Text('One expense'),
                ),
                ButtonSegment(
                  value: BillSaveMode.byCategory,
                  label: Text('By category ($categories)'),
                ),
              ],
              selected: {state.saveMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => onSaveMode(v.first),
            ),
          ] else if (state.mode == ScanMode.lumpsum) ...[
            const SizedBox(height: 2),
            Text(
              'Choose Line items to save each category separately.',
              style: AppTypography.label.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  people == 1
                      ? 'Only me'
                      : 'Shared by $people people · you log your share',
                  style: AppTypography.body.copyWith(color: palette.ink),
                ),
              ),
              IconButton(
                key: const ValueKey('bill-people-less'),
                tooltip: 'One person fewer',
                onPressed: people > 1 ? () => onPeople(people - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Text(
                '$people',
                style: AppTypography.bodyStrong.copyWith(color: palette.ink),
              ),
              IconButton(
                key: const ValueKey('bill-people-more'),
                tooltip: 'One person more',
                onPressed: people < 20 ? () => onPeople(people + 1) : null,
                icon: const Icon(Icons.person_add_alt_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.row,
    required this.onEdit,
    required this.onRemove,
  });
  final ScannedRow row;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListRow(
        icon: Icons.receipt_long_rounded,
        title: row.name,
        titleMaxLines: 2,
        subtitle: row.category,
        onTap: onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmountText.money(row.amount, signed: false),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Remove item',
              icon: const Icon(Icons.close_rounded, size: 20),
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxStrip extends StatelessWidget {
  const _TaxStrip({required this.rows, required this.onRemove});
  final List<ScannedRow> rows;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.surfaceContainerHighest,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: Text(rows[i].name, style: tt.bodyMedium)),
                Text(rows[i].amount.format(), style: tt.bodyMedium),
                IconButton(
                  tooltip: 'Remove tax line',
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onRemove(rows[i].id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReconWarning extends StatelessWidget {
  const _ReconWarning({required this.recon});
  final Reconciliation recon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: AppRadius.field,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'These lines add up to ${recon.computed.format()}, but the '
              'receipt total is ${recon.stated.format()}. Check for a missed '
              'or mis-read line.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.failure);
  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.field,
      ),
      child: Text(
        failure.message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}
