import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../design/design.dart';
import '../../accounts/presentation/wealth_kit.dart';
import '../../price_alerts/domain/price_alert.dart' show formatPrice;
import '../application/investment_editor_controller.dart';
import '../application/investments_providers.dart';
import '../data/live_price_gateway.dart';
import '../data/symbol_search_gateway.dart';
import '../domain/bond.dart';
import '../domain/holding_fields.dart';
import '../domain/investment.dart';
import '../domain/live_price.dart';
import '../domain/symbol_search.dart';

Future<void> openInvestmentForm(
  BuildContext context, {
  InvestmentRecord? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _InvestmentFormSheet(editing: editing),
  );
}

class _InvestmentFormSheet extends ConsumerStatefulWidget {
  const _InvestmentFormSheet({this.editing});
  final InvestmentRecord? editing;

  @override
  ConsumerState<_InvestmentFormSheet> createState() =>
      _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<_InvestmentFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _invested = TextEditingController();
  final _current = TextEditingController();
  final _ticker = TextEditingController();
  final _quantity = TextEditingController();
  // Bonds
  final _face = TextEditingController();
  final _units = TextEditingController();
  final _coupon = TextEditingController();
  final _issuer = TextEditingController();
  BondFrequency _freq = BondFrequency.yearly;
  DateTime? _purchase;
  DateTime? _maturity;
  String? _rating;

  /// Whether the user typed a current value themselves. Until then it
  /// mirrors the amount invested (bonds: invested + accrued interest).
  bool _currentTouched = false;
  late String _asset;
  Timer? _searchTimer;
  int _searchId = 0;
  List<SymbolHit> _hits = const [];
  bool _searching = false;
  String? _goal;
  bool _busy = false;
  Failure? _error;

  bool get _isEditing => widget.editing != null;

  double get _qty => double.tryParse(_quantity.text.trim()) ?? 0;

  /// Priceable asset with a ticker and a quantity: the current value comes
  /// from the live price, not from the user.
  bool get _autoValue =>
      isPriceableAsset(_asset) && _ticker.text.trim().isNotEmpty && _qty > 0;

  /// A throwaway record for the typed ticker/quantity, so the same symbol
  /// resolution as the holding rows is used.
  InvestmentRecord _probe() => InvestmentRecord(
    id: '',
    asset: _asset,
    currency: 'INR',
    fields: {
      'ticker': _ticker.text.trim(),
      if (_asset == 'mutual_funds')
        'units': _quantity.text.trim()
      else
        'quantity': _quantity.text.trim(),
    },
    derived: const {},
  );

  LiveHolding? _liveNow() {
    final prices = <String, double>{
      ...(ref.read(holdingPricesProvider).value ?? const {}),
      ..._fetched,
    };
    return liveFor(_probe(), prices);
  }

  /// Prices fetched for the typed ticker (it may not be a saved holding yet).
  Map<String, double> _fetched = const {};
  Timer? _priceTimer;
  int _priceId = 0;

  Future<Map<String, double>> _lookup() async {
    final want = resolveLiveSymbol(_probe());
    if (want == null) return const {};
    try {
      return await ref.read(livePriceGatewayProvider).fetch([want]);
    } catch (_) {
      return const {};
    }
  }

  void _schedulePrice() {
    _priceTimer?.cancel();
    if (!_autoValue) return;
    final id = ++_priceId;
    _priceTimer = Timer(const Duration(milliseconds: 500), () async {
      final got = await _lookup();
      if (!mounted || id != _priceId || got.isEmpty) return;
      setState(() => _fetched = got);
    });
  }

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _asset = e?.asset ?? 'stocks';
    if (e != null) {
      _name.text = e.name;
      _invested.text = e.invested.amount.toString();
      _current.text = e.current.amount.toString();
      _goal = e.goal;
      _ticker.text = tickerTextOf(e);
      _quantity.text = quantityTextOf(e);
      _currentTouched = true;
      final b = e.bond;
      if (b != null) {
        _face.text = _plain(b.faceValue);
        _units.text = _plain(b.units);
        _coupon.text = _plain(b.couponRate);
        _issuer.text = b.issuer;
        _freq = b.frequency;
        _purchase = b.purchaseDate;
        _maturity = b.maturityDate;
        _rating = b.rating;
      }
    }
    for (final c in [_invested, _face, _units, _coupon]) {
      c.addListener(_syncCurrent);
    }
  }

  static String _plain(double? v) {
    if (v == null) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  bool get _isBond => _asset == 'bonds';

  DateTime get _today => DateTime.now();

  BondTerms _bondTerms() => BondTerms(
    faceValue: double.tryParse(_face.text.trim()),
    units: double.tryParse(_units.text.trim()),
    couponRate: double.tryParse(_coupon.text.trim()),
    frequency: _freq,
    purchaseDate: _purchase,
    maturityDate: _maturity,
    issuer: _issuer.text,
    rating: _rating,
  );

  double get _investedValue => double.tryParse(_invested.text.trim()) ?? 0;

  BondFigures _bondFigures() =>
      BondFigures.of(_bondTerms(), invested: _investedValue, asOf: _today);

  /// What the Current value box shows while the user hasn't typed one.
  String _suggestedCurrent() {
    if (_invested.text.trim().isEmpty) return '';
    if (!_isBond) return _invested.text.trim();
    return _bondFigures().estimatedValue.toStringAsFixed(2);
  }

  void _syncCurrent() {
    if (_currentTouched) return;
    final next = _suggestedCurrent();
    if (_current.text != next) _current.text = next;
    if (mounted) setState(() {});
  }

  void _useCalculated() {
    _currentTouched = false;
    _syncCurrent();
  }

  void _onTickerChanged(String v) {
    _searchTimer?.cancel();
    _schedulePrice();
    setState(() {});
    final id = ++_searchId;
    if (v.trim().length < minSymbolQuery) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      final found = await ref
          .read(symbolSearchGatewayProvider)
          .search(asset: _asset, query: v);
      if (!mounted || id != _searchId) return;
      setState(() {
        _hits = found;
        _searching = false;
      });
    });
  }

  void _pick(SymbolHit hit) {
    _clearSearch();
    _ticker.text = hit.ticker;
    if (_name.text.trim().isEmpty) _name.text = hit.name;
    _schedulePrice();
    setState(() {});
  }

  void _clearSearch() {
    _searchId++;
    _searchTimer?.cancel();
    _hits = const [];
    _searching = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _invested.dispose();
    _current.dispose();
    _ticker.dispose();
    _quantity.dispose();
    _face.dispose();
    _units.dispose();
    _coupon.dispose();
    _issuer.dispose();
    _searchTimer?.cancel();
    _priceTimer?.cancel();
    super.dispose();
  }

  /// Best-effort fresh live value for the typed ticker (null when the price
  /// is not known yet); never throws.
  Future<double?> _fetchLiveValue() async {
    final known = _liveNow()?.value;
    if (known != null) return known;
    return liveFor(_probe(), await _lookup())?.value;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Money current;
    if (_autoValue) {
      final live = (await _fetchLiveValue()) ?? _liveNow()?.value;
      current = live != null
          ? Money(Decimal.parse(live.toStringAsFixed(2)))
          : (_isEditing
                ? widget.editing!.current
                : Money.tryParse(_invested.text)!);
    } else {
      current = Money.tryParse(_current.text)!;
    }
    final draft = InvestmentDraft(
      asset: _asset,
      name: _name.text,
      invested: Money.tryParse(_invested.text)!,
      current: current,
      goal: _goal,
      ticker: isPriceableAsset(_asset) ? _ticker.text : '',
      quantity: isPriceableAsset(_asset) ? _quantity.text : '',
      baseFields: widget.editing?.fields ?? const {},
      bond: _isBond ? _bondTerms() : null,
    );

    setState(() => _busy = true);
    try {
      final c = ref.read(investmentEditorControllerProvider);
      if (_isEditing) {
        await c.update(widget.editing!.id, draft);
      } else {
        await c.create(draft);
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Holding updated' : 'Holding added'),
        ),
      );
    } on Failure catch (f) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = f;
      });
    }
  }

  List<Widget> _liveFields(BuildContext context) {
    final palette = context.palette;
    final fund = _asset == 'mutual_funds';
    final crypto = _asset == 'crypto';
    final helper = fund
        ? 'Type a fund name to search, or enter the scheme code.'
        : crypto
        ? 'Type a coin to search, or enter its code, e.g. BTC.'
        : 'Type a company to search, or enter e.g. NSE:RELIANCE or ITC.NS.';
    return [
      LabeledField(
        label: fund
            ? 'Scheme code (optional)'
            : crypto
            ? 'Coin (optional)'
            : 'Ticker (optional)',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _ticker,
              textCapitalization: fund
                  ? TextCapitalization.none
                  : TextCapitalization.characters,
              autocorrect: false,
              onChanged: _onTickerChanged,
              decoration: InputDecoration(
                hintText: fund ? '119551' : (crypto ? 'BTC' : 'NSE:RELIANCE'),
                prefixIcon: const Icon(Icons.search),
                helperText: helper,
                helperMaxLines: 2,
              ),
              validator: (v) => InvestmentValidators.ticker(v, asset: _asset),
            ),
            if (_searching && _hits.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Searching...',
                  style: AppTypography.label.copyWith(color: palette.muted),
                ),
              ),
            for (final hit in _hits)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pick(hit),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          color: palette.ink,
                        ),
                      ),
                      Text(
                        hit.exchange.isEmpty
                            ? hit.ticker
                            : '${hit.ticker} · ${hit.exchange}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      LabeledField(
        label: fund ? 'Units (optional)' : 'Quantity (optional)',
        child: TextFormField(
          controller: _quantity,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.numbers),
            helperText:
                'With a ticker and quantity, the current value follows the '
                'live price automatically.',
            helperMaxLines: 3,
          ),
          onChanged: (_) {
            _schedulePrice();
            setState(() {});
          },
          validator: InvestmentValidators.quantity,
        ),
      ),
    ];
  }

  Widget _autoValueRow(BuildContext context) {
    final palette = context.palette;
    ref.watch(holdingPricesProvider);
    final value = _liveNow()?.value;
    final symbol = resolveLiveSymbol(_probe())?.symbol ?? '';
    return LabeledField(
      label: 'Current value',
      child: Container(
        key: const ValueKey('auto-current-value'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 18, color: palette.muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value != null
                        ? formatPrice(symbol, value)
                        : 'Calculated once the live price loads',
                    style: AppTypography.bodyStrong.copyWith(
                      color: palette.ink,
                    ),
                  ),
                  Text(
                    'Updates automatically from the live price',
                    style: AppTypography.label.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _dateFmt = DateFormat('d MMM yyyy');
  static final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  Future<void> _pickDate({required bool maturity}) async {
    FocusScope.of(context).unfocus();
    final today = _today;
    final current = maturity ? _maturity : _purchase;
    final first = maturity
        ? (_purchase ?? DateTime(today.year - 40)).add(const Duration(days: 1))
        : DateTime(today.year - 40);
    final last = maturity ? DateTime(today.year + 50) : today;
    var initial =
        current ??
        (maturity ? DateTime(today.year + 5, today.month, today.day) : today);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: maturity ? 'Maturity date' : 'Purchase date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (maturity) {
        _maturity = picked;
      } else {
        _purchase = picked;
      }
    });
    _syncCurrent();
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required FormFieldValidator<String> validator,
    Key? key,
  }) => LabeledField(
    label: label,
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon)),
      validator: validator,
    ),
  );

  List<Widget> _bondFields(BuildContext context) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _numberField(
            key: const ValueKey('bond-face'),
            label: 'Face value per bond',
            controller: _face,
            icon: Icons.sell_outlined,
            hint: '1000',
            validator: BondValidators.positiveOptional,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _numberField(
            key: const ValueKey('bond-units'),
            label: 'Number of bonds',
            controller: _units,
            icon: Icons.numbers,
            hint: '10',
            validator: BondValidators.positiveOptional,
          ),
        ),
      ],
    ),
    _numberField(
      key: const ValueKey('bond-coupon'),
      label: 'Coupon rate (% per year)',
      controller: _coupon,
      icon: Icons.percent_rounded,
      hint: '7.5',
      validator: BondValidators.couponRate,
    ),
    LabeledField(
      label: 'Interest payout',
      child: DropdownButtonFormField<BondFrequency>(
        key: const ValueKey('bond-frequency'),
        initialValue: _freq,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.event_repeat_outlined),
        ),
        items: [
          for (final f in BondFrequency.values)
            DropdownMenuItem(value: f, child: Text(f.label)),
        ],
        onChanged: (v) {
          setState(() => _freq = v ?? _freq);
          _syncCurrent();
        },
      ),
    ),
    _DateFormField(
      key: const ValueKey('bond-purchase'),
      label: 'Purchase date',
      value: _purchase,
      format: _dateFmt,
      onTap: () => _pickDate(maturity: false),
      validator: (_) => BondValidators.purchaseDate(_purchase, today: _today),
    ),
    _DateFormField(
      key: const ValueKey('bond-maturity'),
      label: 'Maturity date',
      value: _maturity,
      format: _dateFmt,
      onTap: () => _pickDate(maturity: true),
      validator: (_) => BondValidators.maturityDate(
        _maturity,
        purchase: _purchase,
        today: _today,
      ),
    ),
    LabeledField(
      label: 'Issuer / ISIN (optional)',
      child: TextFormField(
        controller: _issuer,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          hintText: 'NHAI or INE906B07HH3',
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        validator: (v) =>
            (v?.trim().length ?? 0) > 60 ? 'That is too long' : null,
      ),
    ),
    LabeledField(
      label: 'Credit rating (optional)',
      child: DropdownButtonFormField<String>(
        initialValue: _rating,
        isExpanded: true,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.verified_outlined),
        ),
        items: [
          const DropdownMenuItem<String>(child: Text('Not set')),
          for (final r in kBondRatings)
            DropdownMenuItem(value: r, child: Text(r)),
        ],
        onChanged: (v) => setState(() => _rating = v),
      ),
    ),
  ];

  /// Read-only figures worked out from the terms.
  Widget _bondSummary(BuildContext context) {
    final palette = context.palette;
    final f = _bondFigures();
    final ytm = f.yieldToMaturity;
    final next = f.nextPayout;
    final amount = f.maturityAmount;
    final days = f.daysToMaturity;
    final rows = <(String, String)>[
      ('Yield to maturity', ytm == null ? '—' : '${ytm.toStringAsFixed(2)}%'),
      ('Next payout', next == null ? '—' : _dateFmt.format(next)),
      ('Maturity amount', amount == null ? '—' : _money.format(amount)),
      (
        'Days to maturity',
        days == null ? '—' : NumberFormat.decimalPattern('en_IN').format(days),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        key: const ValueKey('bond-summary'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.label.copyWith(
                          color: palette.muted,
                        ),
                      ),
                    ),
                    Text(
                      value,
                      style: AppTypography.bodyStrong.copyWith(
                        color: palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      formKey: _formKey,
      title: _isEditing ? 'Edit holding' : 'Add holding',
      subtitle: _isBond
          ? "Enter the bond's terms. Yield, payouts and maturity are "
                'worked out for you.'
          : 'Invested and current value. For stocks, crypto and funds add a '
                'ticker and quantity to see the live price. The web app has '
                'the detailed per-asset calculators.',
      primaryLabel: _isEditing ? 'Save changes' : 'Add holding',
      onPrimary: _submit,
      busy: _busy,
      pinActions: true,
      error: _error?.message,
      children: [
        LabeledField(
          label: 'Asset type',
          child: DropdownButtonFormField<String>(
            initialValue: _asset,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final a in kAssetTypes)
                DropdownMenuItem(
                  value: a,
                  child: Row(
                    children: [
                      Icon(assetIcon(a), size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          assetLabel(a),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() {
                _asset = v ?? _asset;
                _clearSearch();
              });
              _syncCurrent();
            },
          ),
        ),
        LabeledField(
          label: 'Name',
          child: TextFormField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: _isBond
                  ? 'e.g. NHAI 7.35% 2031'
                  : 'ITC, Nifty 50 fund…',
              prefixIcon: const Icon(Icons.label_outline),
            ),
            validator: InvestmentValidators.name,
          ),
        ),
        if (isPriceableAsset(_asset)) ..._liveFields(context),
        LabeledField(
          label: 'Amount invested',
          child: TextFormField(
            controller: _invested,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '0',
              prefixIcon: Icon(Icons.south_west_rounded),
            ),
            validator: (v) {
              final e = InvestmentValidators.amount(
                v,
                label: 'the amount invested',
              );
              if (e != null) return e;
              if (_isBond && _investedValue <= 0) {
                return 'Enter an amount above 0';
              }
              return null;
            },
          ),
        ),
        if (_isBond) ..._bondFields(context),
        if (_autoValue)
          _autoValueRow(context)
        else
          LabeledField(
            label: 'Current value',
            child: TextFormField(
              key: const ValueKey('current-value'),
              controller: _current,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _currentTouched = true),
              decoration: InputDecoration(
                hintText: 'Same as amount invested',
                prefixIcon: const Icon(Icons.trending_up),
                helperText: _isBond
                    ? (_currentTouched
                          ? 'Entered by you'
                          : 'Amount invested + interest accrued so far. '
                                'Type to override.')
                    : null,
                helperMaxLines: 2,
                suffixIcon: _isBond && _currentTouched
                    ? IconButton(
                        tooltip: 'Use the calculated value',
                        icon: const Icon(Icons.calculate_outlined),
                        onPressed: _useCalculated,
                      )
                    : null,
              ),
              validator: (v) =>
                  InvestmentValidators.amount(v, label: 'the current value'),
            ),
          ),
        if (_isBond) _bondSummary(context),
        LabeledField(
          label: 'Goal link (optional)',
          child: DropdownButtonFormField<String>(
            initialValue: _goal,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(child: Text('Not set')),
              for (final g in kInvestmentGoals)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _goal = v),
          ),
        ),
      ],
    );
  }
}

/// A tap-to-pick date box that takes part in form validation.
class _DateFormField extends FormField<DateTime> {
  _DateFormField({
    super.key,
    required String label,
    required DateTime? value,
    required DateFormat format,
    required VoidCallback onTap,
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
                 errorText: state.errorText,
               ),
               child: Text(value == null ? '' : format.format(value)),
             ),
           ),
         ),
       );
}
