import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_format.dart';
import '../../../design/design.dart';
import '../../../navigation/quick_add_entry.dart';
import '../../quick_add/presentation/quick_add_sheet.dart';
import '../../workspace/application/workspace_providers.dart';
import '../application/upi_providers.dart';
import '../data/upi_gateway.dart';
import '../domain/upi_qr.dart';

/// Scan & pay: scan a shop's UPI QR, type the amount, and FinRoot hands the
/// payment to the person's own UPI app (Google Pay, PhonePe, Paytm, BHIM…) —
/// then, once it went through, Quick Add opens filled in, so the expense is
/// recorded the moment it is paid. FinRoot never moves money and never sees a
/// UPI PIN. Opened from the home-screen widget, or More → Scan & pay.
class ScanPayScreen extends ConsumerStatefulWidget {
  const ScanPayScreen({super.key});

  static const route = '/scan-pay';

  @override
  ConsumerState<ScanPayScreen> createState() => _ScanPayScreenState();
}

enum _Phase { scanning, unavailable, notUpi, form, paying }

class _ScanPayScreenState extends ConsumerState<ScanPayScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  var _phase = _Phase.scanning;
  var _downloading = false;
  UpiPayee? _payee;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => _phase = _Phase.scanning);
    final result = await ref.read(upiGatewayProvider).scanQr();
    if (!mounted) return;
    switch (result) {
      case QrCancelled():
        // Closed the scanner before scanning anything: leave, as Back would.
        if (_payee == null) {
          _leave();
        } else {
          setState(() => _phase = _Phase.form);
        }
      case QrUnavailable(:final downloading):
        setState(() {
          _phase = _Phase.unavailable;
          _downloading = downloading;
        });
      case QrScanned(:final code):
        final payee = parseUpiQr(code);
        setState(() {
          if (payee == null) {
            _phase = _Phase.notUpi;
            return;
          }
          _payee = payee;
          _phase = _Phase.form;
          _amount.text = payee.amount == null ? '' : _plain(payee.amount!);
          _note.text = '';
        });
    }
  }

  void _leave() {
    if (context.canPop()) context.pop();
  }

  Decimal? get _amountValue {
    final v = Decimal.tryParse(_amount.text.trim());
    return v != null && v > Decimal.zero ? v : null;
  }

  Future<void> _pay() async {
    final payee = _payee;
    final amount = payee?.amount ?? _amountValue;
    if (payee == null || amount == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _phase = _Phase.paying);
    final PayResult result;
    try {
      result = await ref
          .read(upiGatewayProvider)
          .pay(upiPayUri(payee, amount: amount, note: _note.text));
    } on Object {
      if (!mounted) return;
      setState(() => _phase = _Phase.form);
      _say('Couldn\'t open a UPI app. Try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.form);
    switch (result) {
      case NoUpiApp():
        _say(
          'No UPI app on this phone can pay a QR. Install Google Pay, '
          'PhonePe, Paytm or BHIM, then try again.',
        );
      case PayAnswered(:final outcome):
        switch (outcome.status) {
          case UpiStatus.success || UpiStatus.submitted:
            await _record(payee, amount, outcome);
          case UpiStatus.failure:
            _say(
              'The payment didn\'t go through, so nothing was added to '
              'FinRoot.',
            );
          case UpiStatus.unknown:
            if (await _askIfPaid(payee, amount)) {
              await _record(payee, amount, outcome);
            }
        }
    }
  }

  Future<bool> _askIfPaid(UpiPayee payee, Decimal amount) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Did the payment go through?'),
        content: Text(
          'Your UPI app didn\'t say. If ${_money(amount)} reached '
          '${payee.displayName}, add it to FinRoot now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('It didn\'t'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, add it'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  /// Quick Add, filled in with what was paid; the person picks the category
  /// and saves. Then this screen closes either way.
  Future<void> _record(
    UpiPayee payee,
    Decimal amount,
    UpiOutcome outcome,
  ) async {
    final canWrite = ref.read(currentRoleProvider)?.canWrite ?? true;
    if (!canWrite) {
      _say(
        'Paid. Your role in this workspace can\'t add expenses, so it '
        'wasn\'t recorded.',
      );
      _leave();
      return;
    }
    final note = _note.text.trim();
    final saved = await openQuickAdd(
      context,
      prefill: QuickAddPrefill(
        amount: Money(amount),
        note: [
          'Paid ${payee.displayName}',
          if (note.isNotEmpty) note,
          if (outcome.reference != null) 'Ref ${outcome.reference}',
        ].join(' · '),
        paymentMode: 'UPI',
        occurredAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    if (saved != true) {
      _say(
        'Paid, but not added to FinRoot. Add it from Quick Add when you '
        'can.',
      );
    }
    _leave();
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Scan & pay',
      subtitle: 'Pay a shop\'s UPI QR, tracked as you pay',
      body: switch (_phase) {
        _Phase.scanning => const LoadingView(label: 'Opening the scanner…'),
        _Phase.paying => const LoadingView(
          label: 'Finish the payment in your UPI app…',
        ),
        _Phase.unavailable => EmptyView(
          icon: Icons.qr_code_scanner,
          title: _downloading
              ? 'The scanner is still downloading'
              : 'The scanner couldn\'t open',
          message: _downloading
              ? 'Google Play services is fetching the QR scanner for this '
                    'phone. Try again in a minute.'
              : 'The QR scanner comes from Google Play services. Check it '
                    'is up to date, then try again.',
          action: PillButton(label: 'Try again', onPressed: _scan),
        ),
        _Phase.notUpi => EmptyView(
          icon: Icons.qr_code_2,
          title: 'That isn\'t a UPI payment QR',
          message:
              'Scan the shop\'s UPI QR — the one Google Pay, PhonePe or '
              'Paytm would accept.',
          action: PillButton(label: 'Scan again', onPressed: _scan),
        ),
        _Phase.form => _form(context, _payee!),
      },
    );
  }

  Widget _form(BuildContext context, UpiPayee payee) {
    final palette = context.palette;
    final tt = Theme.of(context).textTheme;
    final amount = payee.amount ?? _amountValue;
    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.huge,
      ),
      children: [
        AppCard(
          child: Row(
            children: [
              const IconTile(icon: Icons.storefront_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payee.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (payee.name != null)
                      Text(
                        payee.vpa,
                        style: tt.bodySmall?.copyWith(color: palette.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          key: const ValueKey('scan-pay-amount'),
          controller: _amount,
          readOnly: payee.fixedAmount,
          autofocus: !payee.fixedAmount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?')),
          ],
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: 'Amount',
            prefixText: '₹ ',
            helperText: payee.fixedAmount ? 'Set by the QR' : null,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const ValueKey('scan-pay-note'),
          controller: _note,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: payee.note ?? 'What is it for?',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PillButton(
          label: amount == null
              ? 'Enter an amount'
              : 'Pay ${_money(amount)} with a UPI app',
          icon: Icons.qr_code_scanner,
          expand: true,
          onPressed: amount == null ? null : _pay,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your UPI app opens to finish the payment with your UPI PIN. '
          'FinRoot never sees the PIN and moves no money itself; once it '
          'goes through, Quick Add opens with the expense filled in.',
          style: tt.bodySmall?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a different QR'),
          ),
        ),
      ],
    );
  }
}

/// "₹250", "₹45.50" — paise always in pairs on a payment.
String _money(Decimal v) {
  final s = MoneyFormat.money(v.toDouble());
  return RegExp(r'\.\d$').hasMatch(s) ? '${s}0' : s;
}

/// "250" for 250.00, "99.5" for 99.50 — what a person would type.
String _plain(Decimal v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00')
      ? s.substring(0, s.length - 3)
      : s.endsWith('0')
      ? s.substring(0, s.length - 1)
      : s;
}
