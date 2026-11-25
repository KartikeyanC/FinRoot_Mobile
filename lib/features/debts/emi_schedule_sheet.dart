import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error/failure.dart';
import '../../core/money/money_format.dart';
import '../../design/design.dart';
import '../workspace/application/workspace_providers.dart';
import 'debt_editor.dart';
import 'debts.dart';

final _day = DateFormat('d MMM yyyy');

/// Every EMI of a debt: paid or not, and its amount. Tap one to change its
/// amount (a loan's first or last EMI often differs) or to mark it paid or
/// unpaid — including EMIs paid before the loan was added to FinRoot.
Future<void> openEmiSchedule(BuildContext context, String debtId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _EmiScheduleSheet(debtId: debtId),
    );

class _EmiScheduleSheet extends ConsumerWidget {
  const _EmiScheduleSheet({required this.debtId});
  final String debtId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final debt = ref
        .watch(debtsProvider)
        .value
        ?.where((d) => d.id == debtId)
        .firstOrNull;
    if (debt == null) {
      return const SizedBox(height: 200, child: LoadingView());
    }
    final canWrite = ref.watch(currentRoleProvider)?.canWrite ?? false;
    final today = DateUtils.dateOnly(DateTime.now());

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          0,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          Text(
            '${debt.lender} · EMIs',
            style: AppTypography.title.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 2),
          Text(
            '${debt.paidCount} of ${debt.duration} paid · '
            '${MoneyFormat.money(debt.remaining, currency: debt.currency)} '
            'left of ${MoneyFormat.money(debt.total, currency: debt.currency)}',
            style: AppTypography.body.copyWith(color: palette.muted),
          ),
          if (canWrite) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap an EMI to change its amount or mark it paid.',
              style: AppTypography.label.copyWith(color: palette.muted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < debt.installments.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.line),
                  _EmiRow(
                    debt: debt,
                    emi: debt.installments[i],
                    today: today,
                    onTap: canWrite
                        ? () =>
                              _editEmi(context, ref, debt, debt.installments[i])
                        : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editEmi(
    BuildContext context,
    WidgetRef ref,
    Debt debt,
    DebtInstallment emi,
  ) async {
    final result = await showDialog<({double amount, bool paid})>(
      context: context,
      builder: (_) => _EmiDialog(debt: debt, emi: emi),
    );
    if (result == null || !context.mounted) return;
    final amountChanged = (result.amount - emi.amount).abs() >= 0.005;
    final paidChanged = result.paid != emi.paid;
    if (!amountChanged && !paidChanged) return;
    try {
      await ref
          .read(debtEditorProvider)
          .updateInstallment(
            debt,
            emi.month,
            amount: amountChanged ? result.amount : null,
            paid: paidChanged ? result.paid : null,
          );
    } on Failure catch (f) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      }
    }
  }
}

class _EmiRow extends StatelessWidget {
  const _EmiRow({
    required this.debt,
    required this.emi,
    required this.today,
    required this.onTap,
  });
  final Debt debt;
  final DebtInstallment emi;
  final DateTime today;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finance = context.finance;
    final due = emi.dueDate;
    final overdue = !emi.paid && due != null && due.isBefore(today);
    final status = emi.paid
        ? (emi.backfilled ? 'Paid before FinRoot' : 'Paid')
        : overdue
        ? 'Overdue'
        : 'Due';
    final color = emi.paid
        ? finance.success
        : overdue
        ? finance.expense
        : palette.muted;
    return InkWell(
      key: ValueKey('emi-${emi.month}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              emi.paid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMI ${emi.month}${due == null ? '' : ' · ${_day.format(due)}'}',
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    status,
                    style: AppTypography.label.copyWith(color: color),
                  ),
                ],
              ),
            ),
            Text(
              MoneyFormat.money(emi.amount, currency: debt.currency),
              style: AppTypography.bodyStrong.copyWith(
                color: palette.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.edit_rounded, size: 16, color: palette.muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmiDialog extends StatefulWidget {
  const _EmiDialog({required this.debt, required this.emi});
  final Debt debt;
  final DebtInstallment emi;

  @override
  State<_EmiDialog> createState() => _EmiDialogState();
}

class _EmiDialogState extends State<_EmiDialog> {
  late final _amount = TextEditingController(
    text: widget.emi.amount == widget.emi.amount.roundToDouble()
        ? widget.emi.amount.toInt().toString()
        : widget.emi.amount.toStringAsFixed(2),
  );
  late bool _paid = widget.emi.paid;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    final n = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (n == null || !n.isFinite || n <= 0) {
      setState(() => _error = 'Enter the EMI amount');
      return;
    }
    if (n > 999999999999) {
      setState(() => _error = 'That amount is too large');
      return;
    }
    Navigator.of(context).pop((amount: n, paid: _paid));
  }

  @override
  Widget build(BuildContext context) {
    final due = widget.emi.dueDate;
    return AlertDialog(
      title: Text('EMI ${widget.emi.month} of ${widget.debt.duration}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (due != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text('Due ${_day.format(due)} · ${widget.debt.lender}'),
            ),
          TextField(
            key: const ValueKey('emi-amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile(
            key: const ValueKey('emi-paid'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Paid'),
            subtitle: const Text(
              'Ticks it off. Add the expense too if you want it in your '
              'transactions.',
            ),
            value: _paid,
            onChanged: (v) => setState(() => _paid = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('emi-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
