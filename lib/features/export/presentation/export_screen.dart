import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/presentation/wealth_kit.dart' show FieldLabel;
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../workspace/application/workspace_providers.dart';
import '../domain/csv_export.dart';

/// Hands a finished CSV to the system share sheet. A provider so tests can swap
/// it for a recorder.
typedef CsvSharer = Future<void> Function(String fileName, String csv);

final csvSharerProvider = Provider<CsvSharer>((ref) {
  return (fileName, csv) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(csv, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: fileName,
      ),
    );
  };
}, name: 'csvSharer');

enum ExportRange {
  month('This month'),
  thirtyDays('Last 30 days'),
  year('This year'),
  all('All time');

  const ExportRange(this.label);
  final String label;

  /// `[from, toExclusive)` for [now].
  (DateTime, DateTime) window(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return switch (this) {
      ExportRange.month => (DateTime(now.year, now.month), tomorrow),
      ExportRange.thirtyDays => (
        DateTime(now.year, now.month, now.day - 29),
        tomorrow,
      ),
      ExportRange.year => (DateTime(now.year), tomorrow),
      ExportRange.all => (DateTime(1970), DateTime(now.year + 2)),
    };
  }
}

/// Export the active workspace's transactions as a CSV file.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  ExportRange _range = ExportRange.month;
  TxnType? _type;
  bool _busy = false;
  String? _error;

  Future<void> _export() async {
    final tenantId = ref.read(currentTenantIdProvider);
    if (tenantId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (from, to) = _range.window(DateTime.now());
      final rows = await ref
          .read(transactionsRepositoryProvider)
          .watchBetween(tenantId, from: from, toExclusive: to)
          .first;
      final filtered = filterByType(rows, _type);
      if (filtered.isEmpty) {
        setState(() => _error = 'No transactions match this choice.');
        return;
      }
      final accounts =
          ref.read(workspaceAccountsProvider).value ?? const [];
      final csv = transactionsToCsv(
        filtered,
        accountNames: {for (final a in accounts) a.id: a.name},
      );
      final stamp = DateTime.now();
      final name =
          'finroot-transactions-${stamp.year}'
          '${stamp.month.toString().padLeft(2, '0')}'
          '${stamp.day.toString().padLeft(2, '0')}.csv';
      await ref.read(csvSharerProvider)(name, csv);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn\'t create the file. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(menuStatusProvider(FeatureMenu.export)) ==
        MenuStatus.locked) {
      return const AppPage(
        title: 'Export',
        body: MenuLockedView(
          feature: 'Export',
          icon: Icons.file_download_outlined,
        ),
      );
    }
    final palette = context.palette;
    return AppPage(
      title: 'Export',
      subtitle: 'Download your transactions as a CSV file',
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Period'),
                FilterPills<ExportRange>(
                  selected: _range,
                  onSelected: (r) => setState(() => _range = r),
                  options: [
                    for (final r in ExportRange.values)
                      FilterPill(r, r.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                const FieldLabel('Type'),
                FilterPills<TxnType?>(
                  selected: _type,
                  onSelected: (t) => setState(() => _type = t),
                  options: const [
                    FilterPill(null, 'All'),
                    FilterPill(TxnType.income, 'Income'),
                    FilterPill(TxnType.expense, 'Expenses'),
                    FilterPill(TxnType.transfer, 'Transfers'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Includes date, type, category, note, amount, payment mode '
                  'and account for every matching transaction.',
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _error!,
                    style: AppTypography.bodyStrong.copyWith(
                      color: context.finance.danger,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PillButton(
                  label: _busy ? 'Preparing...' : 'Export CSV',
                  icon: Icons.file_download_outlined,
                  expand: true,
                  onPressed: _busy ? null : _export,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
