import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../application/bill_scan_controller.dart';
import '../domain/scanned_row.dart';

/// Edit one reviewed line — name, category, amount. Corrections here flow into
/// the single approved transaction.
Future<void> openRowEditSheet(
  BuildContext context,
  WidgetRef ref,
  ScannedRow row,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RowEditSheet(row: row),
  );
}

class _RowEditSheet extends ConsumerStatefulWidget {
  const _RowEditSheet({required this.row});
  final ScannedRow row;

  @override
  ConsumerState<_RowEditSheet> createState() => _RowEditSheetState();
}

class _RowEditSheetState extends ConsumerState<_RowEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _category;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.row.name);
    _amount = TextEditingController(text: widget.row.amount.amount.toString());
    _category = kExpenseCategories.contains(widget.row.category)
        ? widget.row.category
        : 'Other';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(billScanControllerProvider.notifier).editRow(
      widget.row.id,
      name: _name.text.trim(),
      category: _category,
      amount: Money.tryParse(_amount.text),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit line',
                style: AppTypography.title.copyWith(
                  color: context.palette.ink,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Description'),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a description' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Category'),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                items: [
                  for (final cat in kExpenseCategories)
                    DropdownMenuItem(value: cat, child: Text(cat)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Label('Amount'),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  final m = Money.tryParse(v ?? '');
                  if (m == null) return 'Enter an amount';
                  if (m.isNegative) return 'Amount cannot be negative';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: _save, child: const Text('Save line')),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: AppTypography.label.copyWith(color: context.palette.muted),
    ),
  );
}
