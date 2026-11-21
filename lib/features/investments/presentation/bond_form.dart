import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../domain/bond.dart';

/// The bond part of the Add holding sheet: its inputs, laid out like an RM's
/// deal sheet (purchase, interest, details), and the read-only figures.
/// [BondFormState] owns the inputs; the sheet listens to it to keep Amount
/// invested and Current value in step.
class BondFormState extends ChangeNotifier {
  BondFormState({BondTerms? initial}) {
    final b = initial;
    if (b != null) {
      face.text = _plain(b.faceValue);
      units.text = _plain(b.units);
      coupon.text = _plain(b.couponRate);
      price.text = _plain(b.price);
      stampDuty.text = _plain(b.stampDuty);
      maturityValue.text = _plain(b.maturityValue);
      tds.text = _plain(b.tdsRate);
      issuer.text = b.issuer;
      frequency = b.frequency;
      purchase = b.purchaseDate;
      maturity = b.maturityDate;
      lastInterest = b.lastInterestDate;
      call = b.callDate;
      rating = b.rating;
      agency = b.ratingAgency;
      bondType = b.bondType;
    }
    for (final c in _numbers) {
      c.addListener(notifyListeners);
    }
  }

  final face = TextEditingController();
  final units = TextEditingController();
  final coupon = TextEditingController();
  final price = TextEditingController();
  final stampDuty = TextEditingController();
  final maturityValue = TextEditingController();
  final tds = TextEditingController();
  final issuer = TextEditingController();
  BondFrequency frequency = BondFrequency.yearly;
  DateTime? purchase;
  DateTime? maturity;
  DateTime? lastInterest;
  DateTime? call;
  String? rating;
  String? agency;
  String? bondType;

  List<TextEditingController> get _numbers => [
    face,
    units,
    coupon,
    price,
    stampDuty,
    maturityValue,
    tds,
  ];

  static String _plain(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  static double? _n(TextEditingController c) => double.tryParse(c.text.trim());

  /// Changes one of the non-text inputs and tells the sheet.
  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  BondTerms terms() => BondTerms(
    faceValue: _n(face),
    units: _n(units),
    couponRate: _n(coupon),
    frequency: frequency,
    purchaseDate: purchase,
    maturityDate: maturity,
    issuer: issuer.text,
    rating: rating,
    ratingAgency: agency,
    price: _n(price),
    lastInterestDate: lastInterest,
    stampDuty: _n(stampDuty),
    maturityValue: _n(maturityValue),
    tdsRate: _n(tds),
    bondType: bondType,
    callDate: call,
  );

  @override
  void dispose() {
    for (final c in [..._numbers, issuer]) {
      c.dispose();
    }
    super.dispose();
  }
}

final _dateFmt = DateFormat('d MMM yyyy');
final _money = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

String bondDate(DateTime d) => _dateFmt.format(d);
String bondMoney(double v) => _money.format(v);

/// A small heading between groups of bond fields.
class BondSectionLabel extends StatelessWidget {
  const BondSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.md),
    child: Text(
      text,
      style: AppTypography.bodyStrong.copyWith(color: context.palette.ink),
    ),
  );
}

Widget _number({
  required String label,
  required TextEditingController controller,
  required IconData icon,
  required String hint,
  required FormFieldValidator<String> validator,
  Key? key,
  String? helper,
}) => LabeledField(
  label: label,
  child: TextFormField(
    key: key,
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      helperText: helper,
      helperMaxLines: 2,
    ),
    validator: validator,
  ),
);

Widget _pair(Widget a, Widget b) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(child: a),
    const SizedBox(width: AppSpacing.md),
    Expanded(child: b),
  ],
);

Widget _select<T>({
  required String label,
  required T? value,
  required List<T> options,
  required String Function(T) text,
  required IconData icon,
  required ValueChanged<T?> onChanged,
  bool optional = true,
  Key? key,
}) => LabeledField(
  label: label,
  child: DropdownButtonFormField<T>(
    key: key,
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(prefixIcon: Icon(icon)),
    items: [
      if (optional) DropdownMenuItem<T>(child: const Text('Not set')),
      for (final o in options)
        DropdownMenuItem<T>(
          value: o,
          child: Text(text(o), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  ),
);

Future<DateTime?> _pick(
  BuildContext context, {
  required DateTime? current,
  required DateTime first,
  required DateTime last,
  required DateTime fallback,
  required String help,
}) {
  FocusScope.of(context).unfocus();
  var initial = current ?? fallback;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: help,
  );
}

/// Face value, units, price, stamp duty, purchase and last IP dates.
List<Widget> bondPurchaseFields(
  BuildContext context,
  BondFormState s, {
  required DateTime today,
}) {
  final cumulative = s.frequency == BondFrequency.atMaturity;
  return [
    const BondSectionLabel('Purchase'),
    _pair(
      _number(
        key: const ValueKey('bond-face'),
        label: 'Face value per bond',
        controller: s.face,
        icon: Icons.sell_outlined,
        hint: '1000',
        validator: BondValidators.positiveOptional,
      ),
      _number(
        key: const ValueKey('bond-units'),
        label: 'Number of bonds',
        controller: s.units,
        icon: Icons.numbers,
        hint: '10',
        validator: BondValidators.positiveOptional,
      ),
    ),
    _pair(
      _number(
        key: const ValueKey('bond-price'),
        label: 'Price per ₹100',
        controller: s.price,
        icon: Icons.price_change_outlined,
        hint: '100',
        validator: BondValidators.price,
      ),
      _number(
        key: const ValueKey('bond-stamp'),
        label: 'Stamp duty',
        controller: s.stampDuty,
        icon: Icons.receipt_outlined,
        hint: '0',
        validator: BondValidators.nonNegativeOptional,
      ),
    ),
    BondDateField(
      key: const ValueKey('bond-purchase'),
      label: 'Purchase date',
      value: s.purchase,
      onTap: () async {
        final d = await _pick(
          context,
          current: s.purchase,
          first: DateTime(today.year - 40),
          last: today,
          fallback: today,
          help: 'Purchase (transaction) date',
        );
        if (d != null) s.update(() => s.purchase = d);
      },
      validator: (_) => BondValidators.purchaseDate(s.purchase, today: today),
    ),
    if (!cumulative)
      BondDateField(
        key: const ValueKey('bond-last-ip'),
        label: 'Last interest payment date (optional)',
        helper:
            '"Last IP date" on the deal sheet. It sets when payouts fall '
            'and the interest paid to or by the seller.',
        value: s.lastInterest,
        onClear: s.lastInterest == null
            ? null
            : () => s.update(() => s.lastInterest = null),
        onTap: () async {
          final base = s.purchase ?? today;
          final d = await _pick(
            context,
            current: s.lastInterest,
            first: DateTime(base.year - 2),
            last: DateTime(base.year + 2),
            fallback: base,
            help: 'Last interest payment date',
          );
          if (d != null) s.update(() => s.lastInterest = d);
        },
        validator: (_) => BondValidators.lastInterestDate(
          s.lastInterest,
          purchase: s.purchase,
          maturity: s.maturity,
          frequency: s.frequency,
        ),
      ),
  ];
}

/// Consideration, accrued interest, stamp duty and cost to client, shown
/// once a price is entered. [onUse] copies the cost into Amount invested.
class BondPurchaseCard extends StatelessWidget {
  const BondPurchaseCard({super.key, required this.figures, this.onUse});

  final BondFigures figures;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final f = figures;
    final cost = f.costToClient;
    if (cost == null) return const SizedBox.shrink();
    final days = f.accruedDaysAtPurchase;
    return _FiguresCard(
      key: const ValueKey('bond-purchase-card'),
      rows: [
        ('Consideration', bondMoney(f.consideration!)),
        (
          'Accrued interest',
          days == null
              ? bondMoney(f.accruedAtPurchase ?? 0)
              : '${bondMoney(f.accruedAtPurchase ?? 0)} ($days days)',
        ),
        ('Cost to client', bondMoney(cost)),
      ],
      action: onUse == null
          ? null
          : TextButton(
              onPressed: onUse,
              child: const Text('Use as amount invested'),
            ),
    );
  }
}

/// Coupon, TDS, frequency, maturity date and value, call date.
List<Widget> bondInterestFields(
  BuildContext context,
  BondFormState s, {
  required DateTime today,
}) => [
  const BondSectionLabel('Interest and maturity'),
  _pair(
    _number(
      key: const ValueKey('bond-coupon'),
      label: 'Coupon rate (% a year)',
      controller: s.coupon,
      icon: Icons.percent_rounded,
      hint: '7.5',
      validator: BondValidators.couponRate,
    ),
    _number(
      key: const ValueKey('bond-tds'),
      label: 'TDS (%)',
      controller: s.tds,
      icon: Icons.account_balance_wallet_outlined,
      hint: '10',
      validator: BondValidators.tdsRate,
    ),
  ),
  _select<BondFrequency>(
    key: const ValueKey('bond-frequency'),
    label: 'Interest payout',
    value: s.frequency,
    options: BondFrequency.values,
    text: (f) => f.label,
    icon: Icons.event_repeat_outlined,
    optional: false,
    onChanged: (v) => s.update(() => s.frequency = v ?? s.frequency),
  ),
  BondDateField(
    key: const ValueKey('bond-maturity'),
    label: 'Maturity date',
    value: s.maturity,
    onTap: () async {
      final first = (s.purchase ?? today).add(const Duration(days: 1));
      final d = await _pick(
        context,
        current: s.maturity,
        first: first,
        last: DateTime(today.year + 50),
        fallback: DateTime(today.year + 5, today.month, today.day),
        help: 'Maturity date',
      );
      if (d != null) s.update(() => s.maturity = d);
    },
    validator: (_) => BondValidators.maturityDate(
      s.maturity,
      purchase: s.purchase,
      today: today,
    ),
  ),
  _number(
    key: const ValueKey('bond-maturity-value'),
    label: 'Maturity value (optional)',
    controller: s.maturityValue,
    icon: Icons.flag_circle_outlined,
    hint: 'Face value × number of bonds',
    validator: BondValidators.positiveOptional,
  ),
  BondDateField(
    key: const ValueKey('bond-call'),
    label: 'Call date (optional)',
    helper: 'When the issuer can redeem early. Leave empty for "NA".',
    value: s.call,
    onClear: s.call == null ? null : () => s.update(() => s.call = null),
    onTap: () async {
      final first = (s.purchase ?? today).add(const Duration(days: 1));
      final d = await _pick(
        context,
        current: s.call,
        first: first,
        last: s.maturity ?? DateTime(today.year + 50),
        fallback: first,
        help: 'Call date',
      );
      if (d != null) s.update(() => s.call = d);
    },
    validator: (_) => BondValidators.callDate(
      s.call,
      purchase: s.purchase,
      maturity: s.maturity,
    ),
  ),
];

/// Issuer / ISIN, rating agency and grade, secured or not.
List<Widget> bondDetailFields(BondFormState s) => [
  const BondSectionLabel('Details'),
  LabeledField(
    label: 'Issuer / ISIN (optional)',
    child: TextFormField(
      controller: s.issuer,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        hintText: 'Navi Finserv or INE342T07668',
        prefixIcon: Icon(Icons.account_balance_outlined),
      ),
      validator: (v) =>
          (v?.trim().length ?? 0) > 60 ? 'That is too long' : null,
    ),
  ),
  _pair(
    _select<String>(
      label: 'Rating agency',
      value: s.agency,
      options: kBondRatingAgencies,
      text: (a) => a,
      icon: Icons.apartment_outlined,
      onChanged: (v) => s.update(() => s.agency = v),
    ),
    _select<String>(
      label: 'Credit rating',
      value: s.rating,
      options: kBondRatings,
      text: (r) => r,
      icon: Icons.verified_outlined,
      onChanged: (v) => s.update(() => s.rating = v),
    ),
  ),
  _select<String>(
    label: 'Bond type (optional)',
    value: s.bondType,
    options: kBondTypes,
    text: (t) => t,
    icon: Icons.shield_outlined,
    onChanged: (v) => s.update(() => s.bondType = v),
  ),
];

/// Yields, payouts (gross and after TDS), interest received, maturity.
class BondSummaryCard extends StatelessWidget {
  const BondSummaryCard({super.key, required this.figures});
  final BondFigures figures;

  @override
  Widget build(BuildContext context) {
    final f = figures;
    final tds = f.tdsRate > 0;
    String payout(double gross) => tds
        ? '${bondMoney(gross)}, ${bondMoney(f.net(gross))} after TDS'
        : bondMoney(gross);
    final next = f.nextPayout;
    final rows = <(String, String)>[
      (
        'Yield to maturity',
        f.yieldToMaturity == null
            ? '—'
            : '${f.yieldToMaturity!.toStringAsFixed(2)}%',
      ),
      if (f.yieldToCall != null)
        ('Yield to call', '${f.yieldToCall!.toStringAsFixed(2)}%'),
      if (f.payoutPerPeriod != null)
        ('Each payout, about', payout(f.payoutPerPeriod!)),
      (
        'Next payout',
        next == null
            ? '—'
            : f.nextPayoutAmount == null || f.payoutPerPeriod == null
            ? bondDate(next)
            : '${bondDate(next)} · ${bondMoney(tds ? f.net(f.nextPayoutAmount!) : f.nextPayoutAmount!)}',
      ),
      if (f.interestReceived > 0)
        (
          'Interest received',
          tds
              ? '${bondMoney(f.net(f.interestReceived))} after TDS'
              : bondMoney(f.interestReceived),
        ),
      (
        'Maturity amount',
        f.maturityAmount == null ? '—' : bondMoney(f.maturityAmount!),
      ),
      (
        'Days to maturity',
        f.daysToMaturity == null
            ? '—'
            : NumberFormat.decimalPattern('en_IN').format(f.daysToMaturity),
      ),
    ];
    return _FiguresCard(key: const ValueKey('bond-summary'), rows: rows);
  }
}

class _FiguresCard extends StatelessWidget {
  const _FiguresCard({super.key, required this.rows, this.action});
  final List<(String, String)> rows;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        label,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 6,
                      child: Text(
                        value,
                        textAlign: TextAlign.end,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}

/// A tap-to-pick date box that takes part in form validation.
class BondDateField extends FormField<DateTime> {
  BondDateField({
    super.key,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
    String? helper,
    super.validator,
  }) : super(
         initialValue: value,
         builder: (state) => LabeledField(
           label: label,
           child: InkWell(
             onTap: onTap,
             borderRadius: AppRadius.field,
             child: InputDecorator(
               isEmpty: value == null,
               decoration: InputDecoration(
                 prefixIcon: const Icon(Icons.event_outlined),
                 hintText: 'Pick a date',
                 helperText: helper,
                 helperMaxLines: 3,
                 errorText: state.errorText,
                 suffixIcon: onClear == null
                     ? null
                     : IconButton(
                         tooltip: 'Clear $label',
                         icon: const Icon(Icons.close),
                         onPressed: onClear,
                       ),
               ),
               child: Text(value == null ? '' : bondDate(value)),
             ),
           ),
         ),
       );
}
